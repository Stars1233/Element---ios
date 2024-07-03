/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2019 New Vector Ltd

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

#import "ThemeService.h"

#ifdef IS_SHARE_EXTENSION
#import "RiotShareExtension-Swift.h"
#else
#import "Riot-Swift.h"
#endif

NSString *const kThemeServiceDidChangeThemeNotification = @"kThemeServiceDidChangeThemeNotification";

@implementation ThemeService
@synthesize themeId = _themeId;

+ (ThemeService *)shared
{
    static ThemeService *sharedOnceInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedOnceInstance = [ThemeService new];
    });
    
    return sharedOnceInstance;
}

- (void)setThemeId:(NSString *)theThemeId
{
    // Update the current theme
    _themeId = theThemeId;
    self.theme = [self themeWithThemeId:self.themeId];
}

- (void)setTheme:(id<Theme> _Nonnull)theme
{
    _theme = theme;
    
    [self updateAppearance];

    [[NSNotificationCenter defaultCenter] postNotificationName:kThemeServiceDidChangeThemeNotification object:nil];
}

- (id<Theme>)themeWithThemeId:(NSString*)themeId
{
    id<Theme> theme;

    if ([themeId isEqualToString:@"auto"])
    {
        // Translate "auto" into a theme
        themeId = UIAccessibilityIsInvertColorsEnabled() ? @"dark" : @"light";
    }

    if ([themeId isEqualToString:@"dark"])
    {
        theme = [DarkTheme new];
    }
    else if ([themeId isEqualToString:@"black"])
    {
        theme = [BlackTheme new];
    }
    else
    {
        // Use light theme by default
        theme = [DefaultTheme new];
    }

    return theme;
}

#pragma mark - Private methods

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        // Riot Colors not yet themeable
        _riotColorBlue = [[UIColor alloc] initWithRgb:0x81BDDB];
        _riotColorCuriousBlue = [[UIColor alloc] initWithRgb:0x2A9EDB];
        _riotColorIndigo = [[UIColor alloc] initWithRgb:0xBD79CC];
        _riotColorOrange = [[UIColor alloc] initWithRgb:0xF8A15F];

        // Observe "Invert Colours" settings changes (available since iOS 11)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessibilityInvertColorsStatusDidChange) name:UIAccessibilityInvertColorsStatusDidChangeNotification object:nil];
    }
    return self;
}

- (void)accessibilityInvertColorsStatusDidChange
{
    // Refresh the theme only for "auto"
    if ([self.themeId isEqualToString:@"auto"])
    {
         self.theme = [self themeWithThemeId:self.themeId];
    }
}

- (void)updateAppearance
{
    [UIScrollView appearance].indicatorStyle = self.theme.scrollBarStyle;
    
    // Define the navigation bar text color
    [[UINavigationBar appearance] setTintColor:self.theme.tintColor];
    
    // Define the UISearchBar cancel button color
    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]] setTitleTextAttributes:@{ NSForegroundColorAttributeName : self.theme.searchPlaceholderColor }                                                                                                        forState: UIControlStateNormal];
}

@end
