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

#import "MXKRoomBubbleCellDataWithAppendingMode.h"

/**
 `RoomBubbleCellData` defines Vector bubble cell data model.
 */
@interface RoomBubbleCellData : MXKRoomBubbleCellDataWithAppendingMode

/**
 A Boolean value that determines whether this bubble contains the current last message.
 Used to keep displaying the timestamp of the last message.
 */
@property(nonatomic) BOOL containsLastMessage;

/**
 A Boolean value that determines whether some read receipts are currently displayed in this bubble.
 */
@property(nonatomic) BOOL hasReadReceipts;

/**
 The event id of the current selected event inside the bubble. Default is nil.
 */
@property(nonatomic) NSString *selectedEventId;

/**
 The index of the most recent component (component with timestamp). NSNotFound by default.
 */
@property(nonatomic, readonly) NSInteger mostRecentComponentIndex;

/**
 The index of the current selected component. NSNotFound by default.
 */
@property(nonatomic, readonly) NSInteger selectedComponentIndex;

@end
