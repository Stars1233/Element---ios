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

#import <MatrixKit/MatrixKit.h>

#import "MediaPickerViewController.h"

/**
 `RoomInputToolbarView` instance is a view used to handle all kinds of available inputs
 for a room (message composer, attachments selection...).
 */
@interface RoomInputToolbarView : MXKRoomInputToolbarViewWithHPGrowingText <MediaPickerViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *mainToolbarView;

@property (weak, nonatomic) IBOutlet UIView *separatorView;
@property (strong, nonatomic) IBOutlet MXKImageView *pictureView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mainToolbarMinHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mainToolbarHeightConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageComposerContainerTrailingConstraint;

@property (weak, nonatomic) IBOutlet UIButton *attachMediaButton;
@property (weak, nonatomic) IBOutlet UIButton *voiceCallButton;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *voiceCallButtonWidthConstraint;

/**
 Tell whether the call option is supported. YES by default.
 */
@property (nonatomic) BOOL supportCallOption;

@end
