/*
 Copyright 2015 OpenMarket Ltd

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

#import "MXKRoomInputToolbarView.h"

#import <HPGrowingTextView/HPGrowingTextView.h>

/**
 `MXKRoomInputToolbarViewWithHPGrowingText` is a MXKRoomInputToolbarView-inherited class in which message
 composer is based on `HPGrowingTextView`.
 
 Toolbar buttons are not overridden by this class. We keep the default implementation.
 */
@interface MXKRoomInputToolbarViewWithHPGrowingText : MXKRoomInputToolbarView <HPGrowingTextViewDelegate>
{
@protected
    HPGrowingTextView *growingTextView;
}

@end
