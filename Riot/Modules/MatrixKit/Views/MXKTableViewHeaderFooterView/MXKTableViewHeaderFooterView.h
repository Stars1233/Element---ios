/*
 Copyright 2017 Vector Creations Ltd
 
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

#import <UIKit/UIKit.h>

/**
 'MXKTableViewHeaderFooterView' class is used to define custom UITableViewHeaderFooterView (Either the header or footer for a section).
 Each 'MXKTableViewHeaderFooterView-inherited' class has its own 'reuseIdentifier'.
 */
@interface MXKTableViewHeaderFooterView : UITableViewHeaderFooterView
{
@protected
    NSString *mxkReuseIdentifier;
}

/**
 Returns the `UINib` object initialized for the header/footer view.
 
 @return The initialized `UINib` object or `nil` if there were errors during
 initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 The default reuseIdentifier of the 'MXKTableViewHeaderFooterView-inherited' class.
 */
+ (NSString*)defaultReuseIdentifier;

/**
 Customize the rendering of the header/footer view and its subviews (Do nothing by default).
 This method is called when the view is initialized or prepared for reuse.
 
 Override this method to customize the view at the application level.
 */
- (void)customizeTableViewHeaderFooterViewRendering;

@end
