/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2020 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "PushNotificationService.h"

#import <MatrixKit/MatrixKit.h>

#import <PushKit/PushKit.h>
#import "Riot-Swift.h"

@interface PushNotificationService()<PKPushRegistryDelegate>

/**
Matrix session observer used to detect new opened sessions.
*/
@property (nonatomic, weak) id matrixSessionStateObserver;
@property (nonatomic, nullable, copy) void (^registrationForRemoteNotificationsCompletion)(NSError *);
@property (nonatomic, strong) PKPushRegistry *pushRegistry;
@property (nonatomic, strong) PushNotificationStore *pushNotificationStore;

/// Should PushNotificationService receive VoIP pushes
@property (nonatomic, assign) BOOL shouldReceiveVoIPPushes;

@end

@implementation PushNotificationService

- (instancetype)initWithPushNotificationStore:(PushNotificationStore *)pushNotificationStore
{
    if (self = [super init])
    {
        self.pushNotificationStore = pushNotificationStore;
        _pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        self.shouldReceiveVoIPPushes = YES;
    }
    return self;
}

#pragma mark - Public Methods

- (void)registerUserNotificationSettings
{
    NSLog(@"[PushNotificationService][Push] registerUserNotificationSettings: isPushRegistered: %@", @(_isPushRegistered));

    if (!_isPushRegistered)
    {
        UNTextInputNotificationAction *quickReply = [UNTextInputNotificationAction
                                                     actionWithIdentifier:@"inline-reply"
                                                     title:NSLocalizedStringFromTable(@"room_message_short_placeholder", @"Vector", nil)
                                                     options:UNNotificationActionOptionAuthenticationRequired
                                                     ];

        UNNotificationCategory *quickReplyCategory = [UNNotificationCategory
                                                      categoryWithIdentifier:@"QUICK_REPLY"
                                                      actions:@[quickReply]
                                                      intentIdentifiers:@[]
                                                      options:UNNotificationCategoryOptionNone];

        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center setNotificationCategories:[[NSSet alloc] initWithArray:@[quickReplyCategory]]];
        [center setDelegate:self];

        UNAuthorizationOptions authorizationOptions = (UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge);

        [center requestAuthorizationWithOptions:authorizationOptions
                              completionHandler:^(BOOL granted, NSError *error)
         { // code here is equivalent to self:application:didRegisterUserNotificationSettings:
             if (granted)
             {
                 [self registerForRemoteNotificationsWithCompletion:nil];
             }
             else
             {
                 // Clear existing token
                 [self clearPushNotificationToken];
             }
         }];
    }
}

- (void)registerForRemoteNotificationsWithCompletion:(nullable void (^)(NSError *))completion
{
    self.registrationForRemoteNotificationsCompletion = completion;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    });
}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"[PushNotificationService][Push] didRegisterForRemoteNotificationsWithDeviceToken");
    
    MXKAccountManager* accountManager = [MXKAccountManager sharedManager];
    [accountManager setApnsDeviceToken:deviceToken];
    
    //  Resurrect old PushKit token to better kill it
    if (!accountManager.pushDeviceToken)
    {
        //  If we don't have the pushDeviceToken, we may have migrated it into the shared user defaults.
        NSString *pushDeviceToken = [MXKAppSettings.standardAppSettings.sharedUserDefaults objectForKey:@"pushDeviceToken"];
        if (pushDeviceToken)
        {
            NSLog(@"[PushNotificationService][Push] didRegisterForRemoteNotificationsWithDeviceToken: Move PushKit token to user defaults");
            
            // Set the token in standard user defaults, as MXKAccount will read it from there when removing the pusher.
            // This will allow to remove the PushKit pusher in the next step
            [[NSUserDefaults standardUserDefaults] setObject:pushDeviceToken forKey:@"pushDeviceToken"];
            
            [MXKAppSettings.standardAppSettings.sharedUserDefaults removeObjectForKey:@"pushDeviceToken"];
            [MXKAppSettings.standardAppSettings.sharedUserDefaults removeObjectForKey:@"pushOptions"];
        }
    }
    
    //  If we already have pushDeviceToken or recovered it in above step, remove its PushKit pusher
    if (accountManager.pushDeviceToken)
    {
        NSLog(@"[PushNotificationService][Push] didRegisterForRemoteNotificationsWithDeviceToken: A PushKit pusher still exists. Remove it");
        
        //  Attempt to remove PushKit pushers explicitly
        [self clearPushNotificationToken];
    }

    _isPushRegistered = YES;
    
    if (!_pushNotificationStore.pushKitToken)
    {
        [self configurePushKit];
    }

    if (self.registrationForRemoteNotificationsCompletion)
    {
        self.registrationForRemoteNotificationsCompletion(nil);
        self.registrationForRemoteNotificationsCompletion = nil;
    }
}

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [self clearPushNotificationToken];

    if (self.registrationForRemoteNotificationsCompletion)
    {
        self.registrationForRemoteNotificationsCompletion(error);
        self.registrationForRemoteNotificationsCompletion = nil;
    }
}

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo
              fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"[PushNotificationService][Push] didReceiveRemoteNotification: applicationState: %tu - payload: %@", [UIApplication sharedApplication].applicationState, userInfo);

    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)deregisterRemoteNotifications
{
    _isPushRegistered = NO;
    self.shouldReceiveVoIPPushes = NO;
}

- (void)applicationWillResignActive
{
    [[UNUserNotificationCenter currentNotificationCenter] removeUnwantedNotifications];
    [[UNUserNotificationCenter currentNotificationCenter] removeCallNotificationsFor:nil];
}

- (void)applicationDidEnterBackground
{
    if (_pushNotificationStore.pushKitToken)
    {
        self.shouldReceiveVoIPPushes = YES;
    }
}

- (void)applicationDidBecomeActive
{
    [[UNUserNotificationCenter currentNotificationCenter] removeUnwantedNotifications];
    [[UNUserNotificationCenter currentNotificationCenter] removeCallNotificationsFor:nil];
    if (_pushNotificationStore.pushKitToken)
    {
        self.shouldReceiveVoIPPushes = NO;
    }
}

- (void)checkPushKitPushersInSession:(MXSession*)session
{
    [session.matrixRestClient pushers:^(NSArray<MXPusher *> *pushers) {
        
        NSLog(@"[PushNotificationService][Push] checkPushKitPushers: %@ has %@ pushers:", session.myUserId, @(pushers.count));
        
        for (MXPusher *pusher in pushers)
        {
            NSLog(@"   - %@", pusher.appId);
            
            // We do not want anymore PushKit pushers the app used to use
            if ([pusher.appId isEqualToString:BuildSettings.pushKitAppIdProd]
                || [pusher.appId isEqualToString:BuildSettings.pushKitAppIdDev])
            {
                [self removePusher:pusher inSession:session];
            }
        }
    } failure:^(NSError *error) {
        NSLog(@"[PushNotificationService][Push] checkPushKitPushers: Error: %@", error);
    }];
}


#pragma mark - Private Methods

- (void)setShouldReceiveVoIPPushes:(BOOL)shouldReceiveVoIPPushes
{
    _shouldReceiveVoIPPushes = shouldReceiveVoIPPushes;
    
    if (_shouldReceiveVoIPPushes && _pushNotificationStore.pushKitToken)
    {
        MXSession *session = [AppDelegate theDelegate].mxSessions.firstObject;
        if (session.state >= MXSessionStateStoreDataReady)
        {
            [self configurePushKit];
        }
        else
        {
            //  add an observer for session state
            MXWeakify(self);

            NSNotificationCenter * __weak notificationCenter = [NSNotificationCenter defaultCenter];
            self.matrixSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                MXStrongifyAndReturnIfNil(self);
                MXSession *mxSession = (MXSession*)notif.object;
                
                if ([[AppDelegate theDelegate].mxSessions containsObject:mxSession]
                    && mxSession.state >= MXSessionStateStoreDataReady
                    && self->_shouldReceiveVoIPPushes)
                {
                    [self configurePushKit];
                    [notificationCenter removeObserver:self.matrixSessionStateObserver];
                }
            }];
        }
    }
    else
    {
        _pushRegistry.delegate = nil;
    }
}

- (void)configurePushKit
{
    _pushRegistry.delegate = self;
    _pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

- (void)removePusher:(MXPusher*)pusher inSession:(MXSession*)session
{
    NSLog(@"[PushNotificationService][Push] removePusher: %@", pusher.appId);
    
    // Shortcut MatrixKit and its complex logic and call directly the API
    [session.matrixRestClient setPusherWithPushkey:pusher.pushkey
                                              kind:[NSNull null]    // This is how we remove a pusher
                                             appId:pusher.appId
                                    appDisplayName:pusher.appDisplayName
                                 deviceDisplayName:pusher.deviceDisplayName
                                        profileTag:pusher.profileTag
                                              lang:pusher.lang
                                              data:pusher.data.JSONDictionary
                                            append:NO
                                           success:^{
        NSLog(@"[PushNotificationService][Push] removePusher: Success");
        
        // Brute clean remaining MatrixKit data
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushDeviceToken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
        
    } failure:^(NSError *error) {
        NSLog(@"[PushNotificationService][Push] removePusher: Error: %@", error);
    }];
}


- (void)launchBackgroundSync
{
    // Launch a background sync for all existing matrix sessions
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in mxAccounts)
    {
        // Check the current session state
        if (account.mxSession.state == MXSessionStatePaused)
        {
            NSLog(@"[PushNotificationService] launchBackgroundSync");
            MXWeakify(self);

            [account backgroundSync:20000 success:^{
                
                // Sanity check
                MXStrongifyAndReturnIfNil(self);
                
                [[UNUserNotificationCenter currentNotificationCenter] removeUnwantedNotifications];
                [[UNUserNotificationCenter currentNotificationCenter] removeCallNotificationsFor:nil];
                NSLog(@"[PushNotificationService] launchBackgroundSync: the background sync succeeds");
            } failure:^(NSError *error) {
                
                NSLog(@"[PushNotificationService] launchBackgroundSync: the background sync failed. Error: %@ (%@).", error.domain, @(error.code));
            }];
        }
    }
}

#pragma mark - UNUserNotificationCenterDelegate

// iOS 10+, see application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
    UNNotification *notification = response.notification;
    UNNotificationContent *content = notification.request.content;
    NSString *actionIdentifier = [response actionIdentifier];
    NSString *roomId = content.userInfo[@"room_id"];

    if ([actionIdentifier isEqualToString:@"inline-reply"])
    {
        if ([response isKindOfClass:[UNTextInputNotificationResponse class]])
        {
            UNTextInputNotificationResponse *textInputNotificationResponse = (UNTextInputNotificationResponse *)response;
            NSString *responseText = [textInputNotificationResponse userText];

            [self handleNotificationInlineReplyForRoomId:roomId withResponseText:responseText success:^(NSString *eventId) {
                completionHandler();
            } failure:^(NSError *error) {

                UNMutableNotificationContent *failureNotificationContent = [[UNMutableNotificationContent alloc] init];
                failureNotificationContent.userInfo = content.userInfo;
                failureNotificationContent.body = NSLocalizedStringFromTable(@"room_event_failed_to_send", @"Vector", nil);
                failureNotificationContent.threadIdentifier = roomId;

                NSString *uuid = [[NSUUID UUID] UUIDString];
                UNNotificationRequest *failureNotificationRequest = [UNNotificationRequest requestWithIdentifier:uuid
                                                                                                         content:failureNotificationContent
                                                                                                         trigger:nil];

                [center addNotificationRequest:failureNotificationRequest withCompletionHandler:nil];
                NSLog(@"[PushNotificationService][Push] didReceiveNotificationResponse: error sending text message: %@", error);

                completionHandler();
            }];
        }
        else
        {
            NSLog(@"[PushNotificationService][Push] didReceiveNotificationResponse: error, expect a response of type UNTextInputNotificationResponse");
            completionHandler();
        }
    }
    else if ([actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier])
    {
        [self notifyNavigateToRoomById:roomId];
        completionHandler();
    }
    else
    {
        NSLog(@"[PushNotificationService][Push] didReceiveNotificationResponse: unhandled identifier %@", actionIdentifier);
        completionHandler();
    }
}

#pragma mark - Other Methods

- (void)handleNotificationInlineReplyForRoomId:(NSString*)roomId
                              withResponseText:(NSString*)responseText
                                       success:(void(^)(NSString *eventId))success
                                       failure:(void(^)(NSError *error))failure
{
    if (!roomId.length)
    {
        failure(nil);
        return;
    }

    NSArray* mxAccounts = [MXKAccountManager sharedManager].activeAccounts;

    __block MXKRoomDataSourceManager* manager;
    dispatch_group_t group = dispatch_group_create();

    for (MXKAccount* account in mxAccounts)
    {
        void(^storeDataReadyBlock)(void) = ^{
            MXRoom* room = [account.mxSession roomWithRoomId:roomId];
            if (room)
            {
                manager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:account.mxSession];
            }
        };
        
        if (account.mxSession.state >= MXSessionStateStoreDataReady)
        {
            storeDataReadyBlock();
            if (manager)
            {
                break;
            }
        }
        else
        {
            dispatch_group_enter(group);
            
            //  wait for session state to be store data ready
            id sessionStateObserver = nil;
            sessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:account.mxSession queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                if (manager)
                {
                    [[NSNotificationCenter defaultCenter] removeObserver:sessionStateObserver];
                    return;
                }
                
                if (account.mxSession.state >= MXSessionStateStoreDataReady)
                {
                    [[NSNotificationCenter defaultCenter] removeObserver:sessionStateObserver];
                    storeDataReadyBlock();
                    dispatch_group_leave(group);
                }
            }];
        }
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (manager == nil)
        {
            NSLog(@"[PushNotificationService][Push] didReceiveNotificationResponse: room with id %@ not found", roomId);
            failure(nil);
        }
        else
        {
            [manager roomDataSourceForRoom:roomId create:YES onComplete:^(MXKRoomDataSource *roomDataSource) {
                if (responseText != nil && responseText.length != 0)
                {
                    NSLog(@"[PushNotificationService][Push] didReceiveNotificationResponse: sending message to room: %@", roomId);
                    [roomDataSource sendTextMessage:responseText success:^(NSString* eventId) {
                        success(eventId);
                    } failure:^(NSError* error) {
                        failure(error);
                    }];
                }
                else
                {
                    failure(nil);
                }
            }];
        }
    });
}

- (void)clearPushNotificationToken
{
    NSLog(@"[PushNotificationService][Push] clearPushNotificationToken: Clear existing token");
    
    // Clear existing pushkit token registered on the HS
    MXKAccountManager* accountManager = [MXKAccountManager sharedManager];
    [accountManager setPushDeviceToken:nil withPushOptions:nil];
}

// Remove delivred notifications for a given room id except call notifications
- (void)removeDeliveredNotificationsWithRoomId:(NSString*)roomId completion:(dispatch_block_t)completion
{
    NSLog(@"[PushNotificationService][Push] removeDeliveredNotificationsWithRoomId: Remove potential delivered notifications for room id: %@", roomId);

    NSMutableArray<NSString*> *notificationRequestIdentifiersToRemove = [NSMutableArray new];

    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];

    [notificationCenter getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {

        for (UNNotification *notification in notifications)
        {
            NSString *threadIdentifier = notification.request.content.threadIdentifier;

            if ([threadIdentifier isEqualToString:roomId])
            {
                [notificationRequestIdentifiersToRemove addObject:notification.request.identifier];
            }
        }

        [notificationCenter removeDeliveredNotificationsWithIdentifiers:notificationRequestIdentifiersToRemove];

        if (completion)
        {
            completion();
        }
    }];
}

#pragma mark - Delegate Notifiers

- (void)notifyNavigateToRoomById:(NSString *)roomId
{
    if ([_delegate respondsToSelector:@selector(pushNotificationService:shouldNavigateToRoomWithId:)])
    {
        [_delegate pushNotificationService:self shouldNavigateToRoomWithId:roomId];
    }
}

#pragma mark - PKPushRegistryDelegate

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)pushCredentials forType:(PKPushType)type
{
    NSLog(@"[PushNotificationService] did update PushKit credentials");
    _pushNotificationStore.pushKitToken = pushCredentials.token;
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
    {
        self.shouldReceiveVoIPPushes = NO;
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion
{
    NSLog(@"[PushNotificationService] didReceiveIncomingPushWithPayload: %@", payload.dictionaryPayload);
    
    NSString *roomId = payload.dictionaryPayload[@"room_id"];
    NSString *eventId = payload.dictionaryPayload[@"event_id"];
    
    [[UNUserNotificationCenter currentNotificationCenter] removeUnwantedNotifications];
    [[UNUserNotificationCenter currentNotificationCenter] removeCallNotificationsFor:roomId];
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
    {
        NSLog(@"[PushNotificationService] didReceiveIncomingPushWithPayload: application is in bg");
        
        if (@available(iOS 13.0, *))
        {
            //  for iOS 13, we'll just report the incoming call in the same runloop. It means we cannot call an async API here.
            MXEvent *lastCallInvite = _pushNotificationStore.lastCallInvite;
            //  remove event
            _pushNotificationStore.lastCallInvite = nil;
            MXSession *session = [AppDelegate theDelegate].mxSessions.firstObject;
            //  when we have a VoIP push while the application is killed, session.callManager will not be ready yet. Configure it.
            [[AppDelegate theDelegate] configureCallManagerIfRequiredForSession:session];
            
            if (lastCallInvite.isEncrypted)
            {
                [session decryptEvent:lastCallInvite inTimeline:nil];
            }
            
            NSLog(@"[PushNotificationService] didReceiveIncomingPushWithPayload: lastCallInvite: %@", lastCallInvite);
            
            if ([lastCallInvite.eventId isEqualToString:eventId])
            {
                [session.callManager handleCallEvent:lastCallInvite];
                MXCall *call = [session.callManager callWithCallId:lastCallInvite.content[@"call_id"]];
                if (call)
                {
                    [session.callManager.callKitAdapter reportIncomingCall:call];
                    NSLog(@"[PushNotificationService] didReceiveIncomingPushWithPayload: Reporting new call in room %@ for the event: %@", roomId, eventId);
                    
                    //  After reporting the call, we can continue async. Launch a background sync to handle call answers/declines on other devices of the user.
                    [self launchBackgroundSync];
                }
                else
                {
                    NSLog(@"[PushNotificationService] didReceiveIncomingPushWithPayload: Error on call object on room %@ for the event: %@", roomId, eventId);
                }
            }
            else
            {
                //  It's a serious error. There is nothing to avoid iOS to kill us here.
                NSLog(@"[PushNotificationService] didReceiveIncomingPushWithPayload: iOS 13 and in bg, but we don't have the last callInvite event for the event %@. There is something wrong.", eventId);
            }
        }
        else
        {
            //  below iOS 13, we can call an async API. After background sync, we'll hopefully fetch the call invite and report a new call to the CallKit.
            [self launchBackgroundSync];
        }
    }
    else
    {
        NSLog(@"[PushNotificationService] didReceiveIncomingPushWithPayload: application is not in bg. There is something wrong.");
    }
    
    completion();
}

@end
