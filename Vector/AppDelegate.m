/*
 Copyright 2014 OpenMarket Ltd
 
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

#import "AppDelegate.h"

#import "RecentsDataSource.h"
#import "RoomDataSource.h"

#import "EventFormatter.h"

#import "HomeViewController.h"
#import "SettingsViewController.h"
#import "RoomViewController.h"

#import "RageShakeManager.h"

#import "NSBundle+MatrixKit.h"

#import "AFNetworkReachabilityManager.h"

#import <AudioToolbox/AudioToolbox.h>

#define MX_CALL_STACK_OPENWEBRTC
#ifdef MX_CALL_STACK_OPENWEBRTC
#import <MatrixOpenWebRTCWrapper/MatrixOpenWebRTCWrapper.h>
#endif

#ifdef MX_CALL_STACK_ENDPOINT
#import <MatrixEndpointWrapper/MatrixEndpointWrapper.h>
#endif

#import "VectorDesignValues.h"

#define MAKE_STRING(x) #x
#define MAKE_NS_STRING(x) @MAKE_STRING(x)

@interface AppDelegate ()
{
    /**
     Reachability observer
     */
    id reachabilityObserver;
    
    /**
     MatrixKit error observer
     */
    id matrixKitErrorObserver;
    
    /**
     matrix session observer used to detect new opened sessions.
     */
    id matrixSessionStateObserver;
    
    /**
     matrix account observers.
     */
    id addedAccountObserver;
    id removedAccountObserver;
    
    /**
     matrix call observer used to handle incoming/outgoing call.
     */
    id matrixCallObserver;
    
    /**
     The current call view controller (if any).
     */
    MXKCallViewController *currentCallViewController;
    
    /**
     Call status window displayed when user goes back to app during a call.
     */
    UIWindow* callStatusBarWindow;
    UIButton* callStatusBarButton;
    
    /**
     Account picker used in case of multiple account.
     */
    MXKAlert *accountPicker;
    
    /**
     Array of `MXSession` instances.
     */
    NSMutableArray *mxSessionArray;
    
    /**
     The room id of the current handled remote notification (if any)
     */
    NSString *remoteNotificationRoomId;
}

@property (strong, nonatomic) MXKAlert *mxInAppNotification;

@end

@implementation AppDelegate

#pragma mark -

+ (AppDelegate*)theDelegate
{
    return (AppDelegate*)[[UIApplication sharedApplication] delegate];
}

#pragma mark -

- (NSString*)appVersion
{
    if (!_appVersion)
    {
        _appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    }
    
    return _appVersion;
}

- (NSString*)build
{
    if (!_build)
    {
        NSString *buildBranch = nil;
        NSString *buildNumber = nil;
        // Check whether GIT_BRANCH and BUILD_NUMBER were provided during compilation in command line argument.
#ifdef GIT_BRANCH
        buildBranch = MAKE_NS_STRING(GIT_BRANCH);
#endif
#ifdef BUILD_NUMBER
        buildNumber = [NSString stringWithFormat:@"#%d", BUILD_NUMBER];
#endif
        if (buildBranch && buildNumber)
        {
            _build = [NSString stringWithFormat:@"%@ %@", buildBranch, buildNumber];
        } else if (buildNumber){
            _build = buildNumber;
        } else
        {
            _build = buildBranch ? buildBranch : NSLocalizedStringFromTable(@"settings_config_no_build_info", @"Vector", nil);
        }
    }
    return _build;
}

- (void)setIsOffline:(BOOL)isOffline
{
    if (!reachabilityObserver)
    {
        // Define reachability observer when isOffline property is set for the first time
        reachabilityObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            
            NSNumber *statusItem = note.userInfo[AFNetworkingReachabilityNotificationStatusItem];
            if (statusItem)
            {
                AFNetworkReachabilityStatus reachabilityStatus = statusItem.integerValue;
                if (reachabilityStatus == AFNetworkReachabilityStatusNotReachable)
                {
                    [AppDelegate theDelegate].isOffline = YES;
                }
                else
                {
                    [AppDelegate theDelegate].isOffline = NO;
                }
            }
            
        }];
    }
    
    _isOffline = isOffline;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifdef DEBUG
    // log the full launchOptions only in DEBUG
    NSLog(@"[AppDelegate] didFinishLaunchingWithOptions: %@", launchOptions);
#else
    NSLog(@"[AppDelegate] didFinishLaunchingWithOptions");
#endif
    
    // Override point for customization after application launch.
    
    // Define the navigation bar text color
    [[UINavigationBar appearance] setTintColor:kVectorColorGreen];
    
    // Customize the localized string table
    [NSBundle mxk_customizeLocalizedStringTableName:@"Vector"];
    
    mxSessionArray = [NSMutableArray array];
    
    // To simplify navigation into the app, we retrieve here the navigation controller and the view controller related
    // to the recents list in Recents Tab.
    // Note: UISplitViewController is not supported on iPhone for iOS < 8.0
    UIViewController* recents = self.window.rootViewController;
    _homeNavigationController = nil;
    if ([recents isKindOfClass:[UISplitViewController class]])
    {
        UISplitViewController *splitViewController = (UISplitViewController *)recents;
        splitViewController.delegate = self;
        
        _homeNavigationController = [splitViewController.viewControllers objectAtIndex:0];
        
        UIViewController *detailsViewController = [splitViewController.viewControllers lastObject];
        if ([detailsViewController isKindOfClass:[UINavigationController class]])
        {
            UINavigationController *navigationController = (UINavigationController*)detailsViewController;
            detailsViewController = navigationController.topViewController;
        }
        
        // IOS >= 8
        if ([splitViewController respondsToSelector:@selector(displayModeButtonItem)])
        {
            detailsViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
            
            // on IOS 8 iPad devices, force to display the primary and the secondary viewcontroller
            // to avoid empty room View Controller in portrait orientation
            // else, the user cannot select a room
            // shouldHideViewController delegate method is also implemented
            if ([splitViewController respondsToSelector:@selector(preferredDisplayMode)] && [(NSString*)[UIDevice currentDevice].model hasPrefix:@"iPad"])
            {
                splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
            }
        }
    }
    else if ([recents isKindOfClass:[UINavigationController class]])
    {
        _homeNavigationController = (UINavigationController*)recents;
    }
    
    if (_homeNavigationController)
    {
        for (UIViewController *viewController in _homeNavigationController.viewControllers)
        {
            if ([viewController isKindOfClass:[HomeViewController class]])
            {
                _homeViewController = (HomeViewController*)viewController;
            }
        }
    }
    
    // Sanity check
    NSAssert(_homeViewController, @"Something wrong in Main.storyboard");
    
    _isAppForeground = NO;
    
    // Retrieve custom configuration
    NSString* userDefaults = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UserDefaults"];
    NSString *defaultsPathFromApp = [[NSBundle mainBundle] pathForResource:userDefaults ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPathFromApp];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Add matrix observers, and initialize matrix sessions if the app is not launched in background.
    [self initMatrixSessions];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationWillResignActive");
    
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    // Release MatrixKit error observer
    if (matrixKitErrorObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:matrixKitErrorObserver];
        matrixKitErrorObserver = nil;
    }
    
    if (self.errorNotification)
    {
        [self.errorNotification dismiss:NO];
        self.errorNotification = nil;
    }
    
    if (accountPicker)
    {
        [accountPicker dismiss:NO];
        accountPicker = nil;
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationDidEnterBackground");
    
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    // Stop reachability monitoring
    if (reachabilityObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
    }
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:nil];
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
    self.isOffline = NO;
    
    // check if some media must be released to reduce the cache size
    [MXKMediaManager reduceCacheSizeToInsert:0];
    
    // Hide potential notification
    if (self.mxInAppNotification)
    {
        [self.mxInAppNotification dismiss:NO];
        self.mxInAppNotification = nil;
    }
    
    // Suspend all running matrix sessions
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in mxAccounts)
    {
        [account pauseInBackgroundTask];
    }
    
    // Refresh the notifications counter
    [self refreshApplicationIconBadgeNumber];
    
    _isAppForeground = NO;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationWillEnterForeground");
    
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    // cancel any background sync before resuming
    // i.e. warn IOS that there is no new data with any received push.
    [self cancelBackgroundSync];
    
    // Open account session(s) if this is not already done (see [initMatrixSessions] in case of background launch).
    [[MXKAccountManager sharedManager] prepareSessionForActiveAccounts];
    
    _isAppForeground = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationDidBecomeActive");
    
    remoteNotificationRoomId = nil;

    // Check if the app crashed last time
    if ([MXLogger crashLog])
    {
#ifndef DEBUG
        // In distributed version, clear the cache to not annoy user more.
        // In debug mode, the developer will be pleased to investigate what is wrong in the cache.
        NSLog(@"[AppDelegate] Clear the cache due to app crash");
        [self reloadMatrixSessions:YES];
#endif

        // Ask the user to send a bug report
        [[RageShakeManager sharedManager] promptCrashReportInViewController:self.window.rootViewController];
    }

    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    // Start monitoring reachability
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        
        // Check whether monitoring is ready
        if (status != AFNetworkReachabilityStatusUnknown)
        {
            if (status == AFNetworkReachabilityStatusNotReachable)
            {
                // Prompt user
                [[AppDelegate theDelegate] showErrorAsAlert:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:@{NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"network_offline_prompt", @"Vector", nil)}]];
            }
            else
            {
                self.isOffline = NO;
            }
            
            [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:nil];
        }
        
    }];
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    
    // Observe matrixKit error to alert user on error
    matrixKitErrorObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKErrorNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        
        [self showErrorAsAlert:note.object];
        
    }];
    
    // Resume all existing matrix sessions
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in mxAccounts)
    {
        [account resume];
    }
    
    // refresh the contacts list
    [MXKContactManager sharedManager].enableFullMatrixIdSyncOnLocalContactsDidLoad = NO;
    [[MXKContactManager sharedManager] loadLocalContacts];
    
    _isAppForeground = YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationWillTerminate");
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Application layout handling

- (void)restoreInitialDisplay:(void (^)())completion
{
    // Dismiss potential media picker
    if (self.window.rootViewController.presentedViewController)
    {
        // Do it asynchronously to avoid hasardous dispatch_async after calling restoreInitialDisplay
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:^{
            
            [self popToHomeViewControllerAnimated:NO];
            
            // Dispatch the completion in order to let navigation stack refresh itself.
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
            
        }];
    }
    else
    {
        [self popToHomeViewControllerAnimated:NO];
        
        // Dispatch the completion in order to let navigation stack refresh itself.
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    }
}

- (MXKAlert*)showErrorAsAlert:(NSError*)error
{
    // Ignore fake error, or connection cancellation error
    if (!error || ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
    {
        return nil;
    }
    
    // Ignore network reachability error when the app is already offline
    if (self.isOffline && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet)
    {
        return nil;
    }
    
    if (self.errorNotification)
    {
        [self.errorNotification dismiss:NO];
    }
    
    NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
    NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    if (!title)
    {
        if (msg)
        {
            title = msg;
            msg = nil;
        }
        else
        {
            title = [NSBundle mxk_localizedStringForKey:@"error"];
        }
    }
    
    self.errorNotification = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
    self.errorNotification.cancelButtonIndex = [self.errorNotification addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                                                    [AppDelegate theDelegate].errorNotification = nil;
                                                }];
    
    [self.errorNotification showInViewController:self.window.rootViewController];
    
    // Switch in offline mode in case of network reachability error
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet)
    {
        self.isOffline = YES;
    }
    
    return self.errorNotification;
}

#pragma mark

- (void)popToHomeViewControllerAnimated:(BOOL)animated
{
    // Force back to the main screen
    if (_homeViewController)
    {
        [_homeNavigationController popToViewController:_homeViewController animated:animated];
        
        // For unknown reason, the navigation bar is not restored correctly by [popToViewController:animated:]
        // when a ViewController has hidden it (see MXKAttachmentsViewController).
        // Patch: restore navigation bar by default here.
        _homeNavigationController.navigationBarHidden = NO;
        
        // For unknown reason, the default settings of the navigation bar are not restored correctly by [popToViewController:animated:]
        // when a ViewController has changed them (see RoomViewController, RoomMemberDetailsViewController).
        // Patch: restore default settings here.
        [_homeNavigationController.navigationBar setShadowImage:nil];
        [_homeNavigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        
        // Release the current selected room
        [_homeViewController closeSelectedRoom];
    }
}

#pragma mark - APNS methods

- (void)registerUserNotificationSettings
{
    if (!isAPNSRegistered)
    {
        // Registration on iOS 8 and later
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeSound |UIUserNotificationTypeAlert) categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [application registerForRemoteNotifications];
}

- (void)application:(UIApplication*)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    NSUInteger len = ((deviceToken.length > 8) ? 8 : deviceToken.length / 2);
    NSLog(@"[AppDelegate] Got APNS token! (%@ ...)", [deviceToken subdataWithRange:NSMakeRange(0, len)]);
    
    MXKAccountManager* accountManager = [MXKAccountManager sharedManager];
    [accountManager setApnsDeviceToken:deviceToken];
    
    isAPNSRegistered = YES;
}

- (void)application:(UIApplication*)app didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    NSLog(@"[AppDelegate] Failed to register for APNS: %@", error);
}

- (void)cancelBackgroundSync
{
    if (_completionHandler)
    {
        _completionHandler(UIBackgroundFetchResultNoData);
        _completionHandler = nil;
    }
}

- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
#ifdef DEBUG
    // log the full userInfo only in DEBUG
    NSLog(@"[AppDelegate] didReceiveRemoteNotification: %@", userInfo);
#else
    NSLog(@"[AppDelegate] didReceiveRemoteNotification");
#endif
    
    // Look for the room id
    NSString* roomId = [userInfo objectForKey:@"room_id"];
    if (roomId.length)
    {
        // TODO retrieve the right matrix session
        
        //**************
        // Patch consider the first session which knows the room id
        MXKAccount *dedicatedAccount = nil;
        
        NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
        
        if (mxAccounts.count == 1)
        {
            dedicatedAccount = mxAccounts.firstObject;
        }
        else
        {
            for (MXKAccount *account in mxAccounts)
            {
                if ([account.mxSession roomWithRoomId:roomId])
                {
                    dedicatedAccount = account;
                    break;
                }
            }
        }
        
        // sanity checks
        if (dedicatedAccount && dedicatedAccount.mxSession)
        {
            UIApplicationState state = [UIApplication sharedApplication].applicationState;
            
            // Jump to the concerned room only if the app is transitioning from the background
            if (state == UIApplicationStateInactive)
            {
                // Check whether another remote notification is not already processed
                if (!remoteNotificationRoomId)
                {
                    remoteNotificationRoomId = roomId;
                    
                    NSLog(@"[AppDelegate] didReceiveRemoteNotification: open the roomViewController %@", roomId);
                    
                    [self showRoom:roomId withMatrixSession:dedicatedAccount.mxSession];
                }
                else
                {
                    NSLog(@"[AppDelegate] didReceiveRemoteNotification: busy");
                }
            }
            else if (!_completionHandler && (state == UIApplicationStateBackground))
            {
                _completionHandler = completionHandler;

                NSLog(@"[AppDelegate] : starts a background sync");
                
                [dedicatedAccount backgroundSync:20000 success:^{
                    NSLog(@"[AppDelegate]: the background sync succeeds");
                    
                    if (_completionHandler)
                    {
                        _completionHandler(UIBackgroundFetchResultNewData);
                        _completionHandler = nil;
                    }
                } failure:^(NSError *error) {
                    NSLog(@"[AppDelegate]: the background sync fails");
                    
                    if (_completionHandler)
                    {
                        _completionHandler(UIBackgroundFetchResultNoData);
                        _completionHandler = nil;
                    }
                }];
                
                // wait that the background sync is done
                return;
            }
        }
        else
        {
            NSLog(@"[AppDelegate]: didReceiveRemoteNotification : no linked session / account has been found.");
        }
    }
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)refreshApplicationIconBadgeNumber
{
    NSLog(@"[AppDelegate] refreshApplicationIconBadgeNumber");
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = [MXKRoomDataSourceManager notificationCount];
}

#pragma mark - Matrix sessions handling

- (void)initMatrixSessions
{
    // Disable identicon use
    [MXSDKOptions sharedInstance].disableIdenticonUseForUserAvatar = YES;
    
    // Disable long press on event in bubble cells
    [MXKRoomBubbleTableViewCell disableLongPressGestureOnEvent:YES];
    
    // Set first RoomDataSource class used in Vector
    [MXKRoomDataSourceManager registerRoomDataSourceClass:RoomDataSource.class];
    
    // Register matrix session state observer in order to handle multi-sessions.
    matrixSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif)
    {
        MXSession *mxSession = (MXSession*)notif.object;
        
        // Remove by default potential call observer on matrix session state change
        if (matrixCallObserver)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:matrixCallObserver];
            matrixCallObserver = nil;
        }
        
        // Check whether the concerned session is a new one
        if (mxSession.state == MXSessionStateInitialised)
        {
            // Store this new session
            [self addMatrixSession:mxSession];
            
            // Set the VoIP call stack (if supported).
            id<MXCallStack> callStack;
            
#ifdef MX_CALL_STACK_OPENWEBRTC
            callStack = [[MXOpenWebRTCCallStack alloc] init];
#endif
#ifdef MX_CALL_STACK_ENDPOINT
            callStack = [[MXEndpointCallStack alloc] initWithMatrixId:mxSession.myUser.userId];
#endif
            if (callStack)
            {
                [mxSession enableVoIPWithCallStack:callStack];
            }
            
            // Each room member will be considered as a potential contact.
            [MXKContactManager sharedManager].contactManagerMXRoomSource = MXKContactManagerMXRoomSourceAll;
        }
        else if (mxSession.state == MXSessionStateStoreDataReady)
        {
            // Check whether the app user wants inApp notifications on new events for this session
            NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
            for (MXKAccount *account in mxAccounts)
            {
                if (account.mxSession == mxSession)
                {
                    [self enableInAppNotificationsForAccount:account];
                    break;
                }
            }
        }
        else if (mxSession.state == MXSessionStateClosed)
        {
            [self removeMatrixSession:mxSession];
        }
        
        // Restore call observer only if all session are running
        NSArray *mxSessions = self.mxSessions;
        BOOL shouldAddMatrixCallObserver = (mxSessions.count);
        for (mxSession in mxSessions)
        {
            if (mxSession.state != MXSessionStateRunning)
            {
                shouldAddMatrixCallObserver = NO;
                break;
            }
        }
        
        if (shouldAddMatrixCallObserver)
        {
            // A new call observer may be added here
            [self addMatrixCallObserver];
        }
    }];
    
    // Register an observer in order to handle new account
    addedAccountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidAddAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Finalize the initialization of this new account
        MXKAccount *account = notif.object;
        if (account)
        {
            // Set the push gateway URL.
            account.pushGatewayURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushGatewayURL"];
            
            if (isAPNSRegistered)
            {
                // Enable push notifications by default on new added account
                account.enablePushNotifications = YES;
            }
            else
            {
                // Set up push notifications
                [self registerUserNotificationSettings];
            }
            
            // Observe inApp notifications toggle change
            [account addObserver:self forKeyPath:@"enableInAppNotifications" options:0 context:nil];
        }
    }];
    
    // Add observer to handle removed accounts
    removedAccountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidRemoveAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Remove inApp notifications toggle change
        MXKAccount *account = notif.object;
        [account removeObserver:self forKeyPath:@"enableInAppNotifications"];
        
        // Logout the app when there is no available account
        if (![MXKAccountManager sharedManager].accounts.count)
        {
            [self logout];
        }
    }];
    
    // Observe settings changes
    [[MXKAppSettings standardAppSettings]  addObserver:self forKeyPath:@"showAllEventsInRoomHistory" options:0 context:nil];
    
    // Prepare account manager
    MXKAccountManager *accountManager = [MXKAccountManager sharedManager];
    
    // Use MXFileStore as MXStore to permanently store events.
    accountManager.storeClass = [MXFileStore class];

    // Observers have been defined, we can start a matrix session for each enabled accounts.
    // except if the app is still in background.
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground)
    {
        [accountManager prepareSessionForActiveAccounts];
    }
    else
    {
        // The app is launched in background as a result of a remote notification.
        // Presently we are not able to initialize the matrix session(s) in background. (FIXME: initialize matrix session(s) in case of a background launch).
        // Patch: the account session(s) will be opened when the app will enter foreground.
        NSLog(@"[AppDelegate] initMatrixSessions: The application has been launched in background");
    }
    
    // Check whether we're already logged in
    NSArray *mxAccounts = accountManager.accounts;
    if (mxAccounts.count)
    {
        // The push gateway url is now configurable.
        // Set this url in the existing accounts when it is undefined.
        for (MXKAccount *account in mxAccounts)
        {
            if (!account.pushGatewayURL)
            {
                // Set the push gateway URL.
                account.pushGatewayURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushGatewayURL"];
            }
        }
        
        // Set up push notifications
        [self registerUserNotificationSettings];
        
        // Observe inApp notifications toggle change for each account
        for (MXKAccount *account in mxAccounts)
        {
            [account addObserver:self forKeyPath:@"enableInAppNotifications" options:0 context:nil];
        }
    }
}

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}

- (void)addMatrixSession:(MXSession *)mxSession
{
    if (mxSession)
    {
        // Report this session to contact manager
        [[MXKContactManager sharedManager] addMatrixSession:mxSession];
        
        // Update recents data source (The recents view controller will be updated by its data source)
        if (!mxSessionArray.count)
        {
            // This is the first added session, list all the recents for the logged user
            [_homeViewController displayWithSession:mxSession];
        }
        else
        {
            [_homeViewController addMatrixSession:mxSession];
        }
        
        [mxSessionArray addObject:mxSession];
    }
}

- (void)removeMatrixSession:(MXSession*)mxSession
{
    [[MXKContactManager sharedManager] removeMatrixSession:mxSession];
    
    // Update home data sources
    [_homeViewController removeMatrixSession:mxSession];
    
    [mxSessionArray removeObject:mxSession];
}

- (void)reloadMatrixSessions:(BOOL)clearCache
{
    // Reload all running matrix sessions
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in mxAccounts)
    {
        [account reload:clearCache];
    }
    
    // Force back to Recents list if room details is displayed (Room details are not available until the end of initial sync)
    [self popToHomeViewControllerAnimated:NO];
    
    if (clearCache)
    {
        // clear the media cache
        [MXKMediaManager clearCache];
    }
}

- (void)logout
{
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    isAPNSRegistered = NO;
    
    // Clear cache
    [MXKMediaManager clearCache];

#ifdef MX_CALL_STACK_ENDPOINT
    // Erase all created certificates and private keys by MXEndpointCallStack
    for (MXKAccount *account in MXKAccountManager.sharedManager.accounts)
    {
        if ([account.mxSession.callManager.callStack isKindOfClass:MXEndpointCallStack.class])
        {
            [(MXEndpointCallStack*)account.mxSession.callManager.callStack deleteData:account.mxSession.myUser.userId];
        }
    }
#endif
    
    // Logout all matrix account
    [[MXKAccountManager sharedManager] logout];
    
    // Return to authentication screen
    [_homeViewController showAuthenticationScreen];
    
    // Reset App settings
    [[MXKAppSettings standardAppSettings] reset];
    
    // Reset the contact manager
    [[MXKContactManager sharedManager] reset];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([@"showAllEventsInRoomHistory" isEqualToString:keyPath])
    {
        // Flush and restore Matrix data
        [self reloadMatrixSessions:NO];
    }
    else if ([@"enableInAppNotifications" isEqualToString:keyPath] && [object isKindOfClass:[MXKAccount class]])
    {
        [self enableInAppNotificationsForAccount:(MXKAccount*)object];
    }
}

- (void)addMatrixCallObserver
{
    if (matrixCallObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:matrixCallObserver];
    }
    
    // Register call observer in order to handle new opened session
    matrixCallObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallManagerNewCall object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif)
    {
        
        // Ignore the call if a call is already in progress
        if (!currentCallViewController)
        {
            MXCall *mxCall = (MXCall*)notif.object;
            
            currentCallViewController = [MXKCallViewController callViewController:mxCall];
            currentCallViewController.delegate = self;
            
            // FIXME GFO Check whether present call from self.window.rootViewController is working
            [self.window.rootViewController presentViewController:currentCallViewController animated:YES completion:^{
                currentCallViewController.isPresented = YES;
            }];
            
            // Hide system status bar
            [UIApplication sharedApplication].statusBarHidden = YES;
        }
    }];
}

#pragma mark - Matrix Accounts handling

- (void)enableInAppNotificationsForAccount:(MXKAccount*)account
{
    if (account.mxSession)
    {
        if (account.enableInAppNotifications)
        {
            // Build MXEvent -> NSString formatter
            EventFormatter *eventFormatter = [[EventFormatter alloc] initWithMatrixSession:account.mxSession];
            eventFormatter.isForSubtitle = YES;
            
            [account listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {
                
                // Check conditions to display this notification
                if (![self.visibleRoomId isEqualToString:event.roomId]
                    && !self.window.rootViewController.presentedViewController)
                {
                    MXKEventFormatterError error;
                    NSString* messageText = [eventFormatter stringFromEvent:event withRoomState:roomState error:&error];
                    if (messageText.length && (error == MXKEventFormatterErrorNone))
                    {
                        
                        // Removing existing notification (if any)
                        if (self.mxInAppNotification)
                        {
                            [self.mxInAppNotification dismiss:NO];
                        }
                        
                        // Check whether tweak is required
                        for (MXPushRuleAction *ruleAction in rule.actions)
                        {
                            if (ruleAction.actionType == MXPushRuleActionTypeSetTweak)
                            {
                                if ([[ruleAction.parameters valueForKey:@"set_tweak"] isEqualToString:@"sound"])
                                {
                                    // Play system sound (VoicemailReceived)
                                    AudioServicesPlaySystemSound (1002);
                                }
                            }
                        }
                        
                        __weak typeof(self) weakSelf = self;
                        self.mxInAppNotification = [[MXKAlert alloc] initWithTitle:roomState.displayname
                                                                           message:messageText
                                                                             style:MXKAlertStyleAlert];
                        self.mxInAppNotification.cancelButtonIndex = [self.mxInAppNotification addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                                                                            style:MXKAlertActionStyleDefault
                                                                                                          handler:^(MXKAlert *alert)
                                                                      {
                                                                          weakSelf.mxInAppNotification = nil;
                                                                          [account updateNotificationListenerForRoomId:event.roomId ignore:YES];
                                                                      }];
                        [self.mxInAppNotification addActionWithTitle:NSLocalizedStringFromTable(@"view", @"Vector", nil)
                                                               style:MXKAlertActionStyleDefault
                                                             handler:^(MXKAlert *alert)
                         {
                             weakSelf.mxInAppNotification = nil;
                             // Show the room
                             [weakSelf showRoom:event.roomId withMatrixSession:account.mxSession];
                         }];
                        
                        [self.mxInAppNotification showInViewController:self.window.rootViewController];
                    }
                }
            }];
        }
        else
        {
            [account removeNotificationListener];
        }
    }
    
    if (self.mxInAppNotification)
    {
        [self.mxInAppNotification dismiss:NO];
        self.mxInAppNotification = nil;
    }
}

- (void)selectMatrixAccount:(void (^)(MXKAccount *selectedAccount))onSelection
{
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    
    if (mxAccounts.count == 1)
    {
        if (onSelection)
        {
            onSelection(mxAccounts.firstObject);
        }
    }
    else if (mxAccounts.count > 1)
    {
        if (accountPicker)
        {
            [accountPicker dismiss:NO];
        }
        
        accountPicker = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"select_account"] message:nil style:MXKAlertStyleActionSheet];
        
        __weak typeof(self) weakSelf = self;
        for(MXKAccount *account in mxAccounts)
        {
            [accountPicker addActionWithTitle:account.mxCredentials.userId style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->accountPicker = nil;
                
                if (onSelection)
                {
                    onSelection(account);
                }
            }];
        }
        
        accountPicker.cancelButtonIndex = [accountPicker addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
            
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->accountPicker = nil;
            
            if (onSelection)
            {
                onSelection(nil);
            }
        }];
        
        accountPicker.sourceView = self.window.rootViewController.view;
        [accountPicker showInViewController:self.window.rootViewController];
    }
}

#pragma mark - Matrix Rooms handling

- (void)showRoom:(NSString*)roomId withMatrixSession:(MXSession*)mxSession
{
    [self restoreInitialDisplay:^{
        
        // Select room to display its details (dispatch this action in order to let TabBarController end its refresh)
        [_homeViewController selectRoomWithId:roomId inMatrixSession:mxSession];
        
    }];
}

- (void)setVisibleRoomId:(NSString *)roomId
{
    if (roomId)
    {
        // Enable inApp notification for this room in all existing accounts.
        NSArray *mxAccounts = [MXKAccountManager sharedManager].accounts;
        for (MXKAccount *account in mxAccounts)
        {
            [account updateNotificationListenerForRoomId:roomId ignore:NO];
        }
    }
    
    _visibleRoomId = roomId;
}

- (void)startPrivateOneToOneRoomWithUserId:(NSString*)userId completion:(void (^)(void))completion
{
    // Handle here potential multiple accounts
    [self selectMatrixAccount:^(MXKAccount *selectedAccount) {
        
        MXSession *mxSession = selectedAccount.mxSession;
        
        if (mxSession)
        {
            MXRoom* mxRoom = [mxSession privateOneToOneRoomWithUserId:userId];
            
            // if the room exists
            if (mxRoom)
            {
                // open it
                [self showRoom:mxRoom.state.roomId withMatrixSession:mxSession];
                
                if (completion)
                {
                    completion();
                }
            }
            else
            {
                // create a new room
                [mxSession createRoom:nil
                           visibility:kMXRoomVisibilityPrivate
                            roomAlias:nil
                                topic:nil
                              success:^(MXRoom *room) {
                                  
                                  // Invite the other user only if it is defined and not onself
                                  if (userId && ![mxSession.myUser.userId isEqualToString:userId])
                                  {
                                      // Add the user
                                      [room inviteUser:userId
                                               success:^{
                                               }
                                               failure:^(NSError *error) {
                                                   
                                                   NSLog(@"[AppDelegate] %@ invitation failed (roomId: %@)", userId, room.state.roomId);
                                                   //Alert user
                                                   [self showErrorAsAlert:error];
                                                   
                                               }];
                                  }
                                  
                                  // Open created room
                                  [self showRoom:room.state.roomId withMatrixSession:mxSession];
                                  
                                  if (completion)
                                  {
                                      completion();
                                  }
                                  
                              }
                              failure:^(NSError *error) {
                                  
                                  NSLog(@"[AppDelegate] Create room failed");
                                  //Alert user
                                  [self showErrorAsAlert:error];
                                  
                                  if (completion)
                                  {
                                      completion();
                                  }
                                  
                              }];
            }
        }
        else if (completion)
        {
            completion();
        }
        
    }];
}

#pragma mark - MXKCallViewControllerDelegate

- (void)dismissCallViewController:(MXKCallViewController *)callViewController
{
    if (callViewController == currentCallViewController)
    {
        
        if (callViewController.isPresented)
        {
            BOOL callIsEnded = (callViewController.mxCall.state == MXCallStateEnded);
            NSLog(@"Call view controller is dismissed (%d)", callIsEnded);
            
            [callViewController dismissViewControllerAnimated:YES completion:^{
                callViewController.isPresented = NO;
                
                if (!callIsEnded)
                {
                    [self addCallStatusBar];
                }
            }];
            
            if (callIsEnded)
            {
                [self removeCallStatusBar];
                
                // Restore system status bar
                [UIApplication sharedApplication].statusBarHidden = NO;
                
                // Release properly
                currentCallViewController.mxCall.delegate = nil;
                currentCallViewController.delegate = nil;
                currentCallViewController = nil;
            }
        } else
        {
            // Here the presentation of the call view controller is in progress
            // Postpone the dismiss
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissCallViewController:callViewController];
            });
        }
    }
}

#pragma mark - MXKContactDetailsViewControllerDelegate

- (void)contactDetailsViewController:(MXKContactDetailsViewController *)contactDetailsViewController startChatWithMatrixId:(NSString *)matrixId completion:(void (^)(void))completion
{
    [self startPrivateOneToOneRoomWithUserId:matrixId completion:completion];
}

#pragma mark - MXKRoomMemberDetailsViewControllerDelegate

- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController startChatWithMemberId:(NSString *)matrixId completion:(void (^)(void))completion
{
    [self startPrivateOneToOneRoomWithUserId:matrixId completion:completion];
}

#pragma mark - Call status handling

- (void)addCallStatusBar
{
    // Add a call status bar
    CGSize topBarSize = CGSizeMake([[UIScreen mainScreen] applicationFrame].size.width, 44);
    
    callStatusBarWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0,0, topBarSize.width,topBarSize.height)];
    callStatusBarWindow.windowLevel = UIWindowLevelStatusBar;
    
    // Create statusBarButton
    callStatusBarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    callStatusBarButton.frame = CGRectMake(0, 0, topBarSize.width,topBarSize.height);
    NSString *btnTitle = NSLocalizedStringFromTable(@"return_to_call", @"Vector", nil);
    
    [callStatusBarButton setTitle:btnTitle forState:UIControlStateNormal];
    [callStatusBarButton setTitle:btnTitle forState:UIControlStateHighlighted];
    callStatusBarButton.titleLabel.textColor = [UIColor whiteColor];
    
    [callStatusBarButton setBackgroundColor:[UIColor blueColor]];
    [callStatusBarButton addTarget:self action:@selector(returnToCallView) forControlEvents:UIControlEventTouchUpInside];
    
    // Place button into the new window
    [callStatusBarWindow addSubview:callStatusBarButton];
    
    callStatusBarWindow.hidden = NO;
    [self statusBarDidChangeFrame];
    
    // We need to listen to the system status bar size change events to refresh the root controller frame.
    // Else the navigation bar position will be wrong.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarDidChangeFrame)
                                                 name:UIApplicationDidChangeStatusBarFrameNotification
                                               object:nil];
}

- (void)removeCallStatusBar
{
    if (callStatusBarWindow)
    {
        
        // Hide & destroy it
        callStatusBarWindow.hidden = YES;
        [self statusBarDidChangeFrame];
        [callStatusBarButton removeFromSuperview];
        callStatusBarButton = nil;
        callStatusBarWindow = nil;
        
        // No more need to listen to system status bar changes
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    }
}

- (void)returnToCallView
{
    [self removeCallStatusBar];
    
    // FIXME GFO check whether self.window.rootViewController may present the call
    [self.window.rootViewController presentViewController:currentCallViewController animated:YES completion:^{
        currentCallViewController.isPresented = YES;
    }];
}

- (void)statusBarDidChangeFrame
{
    UIApplication *app = [UIApplication sharedApplication];
    UIViewController *rootController = app.keyWindow.rootViewController;
    
    // Refresh the root view controller frame
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    if (callStatusBarWindow)
    {
        // Substract the height of call status bar from the frame.
        CGFloat callBarStatusHeight = callStatusBarWindow.frame.size.height;
        
        CGFloat delta = callBarStatusHeight - frame.origin.y;
        frame.origin.y = callBarStatusHeight;
        frame.size.height -= delta;
    }
    rootController.view.frame = frame;
    [rootController.view setNeedsLayout];
}

#pragma mark - SplitViewController delegate

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController
{
    if ([secondaryViewController isKindOfClass:[UINavigationController class]] && [[(UINavigationController *)secondaryViewController topViewController] isKindOfClass:[RoomViewController class]] && ([(RoomViewController *)[(UINavigationController *)secondaryViewController topViewController] roomDataSource] == nil))
    {
        // Return YES to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    // oniPad devices, force to display the primary and the secondary viewcontroller
    // to avoid empty room View Controller in portrait orientation
    // else, the user cannot select a room
    return NO;
}

@end
