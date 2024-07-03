/*
 Copyright 2016 OpenMarket Ltd
 
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

#import "SimpleRoomTitleView.h"

#import "VectorDesignValues.h"

#import "MXRoom+Vector.h"

@implementation SimpleRoomTitleView

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([SimpleRoomTitleView class])
                          bundle:[NSBundle bundleForClass:[SimpleRoomTitleView class]]];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.displayNameTextField.textColor = kVectorTextColorBlack;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.superview)
    {
        // Center horizontally the display name into the navigation bar
        CGRect frame = self.superview.frame;
        UINavigationBar *navigationBar;
        UIView *superView = self;
        while (superView.superview)
        {
            if ([superView.superview isKindOfClass:[UINavigationBar class]])
            {
                navigationBar = (UINavigationBar*)superView.superview;
                break;
            }
            
            superView = superView.superview;
        }
        
        if (navigationBar)
        {
            CGSize navBarSize = navigationBar.frame.size;
            CGFloat superviewCenterX = frame.origin.x + (frame.size.width / 2);
            
            // Center the display name
            self.displayNameCenterXConstraint.constant = (navBarSize.width / 2) - superviewCenterX;
        }        
    }
}

- (void)refreshDisplay
{
    [super refreshDisplay];
    
    if (self.mxRoom)
    {
        self.displayNameTextField.text = self.mxRoom.vectorDisplayname;
        if (!self.displayNameTextField.text.length)
        {
            self.displayNameTextField.text = NSLocalizedStringFromTable(@"room_displayname_no_title", @"Vector", nil);
            self.displayNameTextField.textColor = kVectorTextColorGray;
        }
        else
        {
            self.displayNameTextField.textColor = kVectorTextColorBlack;
        }
    }
}

@end
