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

#import "RecentCellData.h"

#import "MXRoom+Vector.h"

@implementation RecentCellData
// trick to hide the mother class property as it is readonly one.
// self.roomDisplayname returns this value instead of the mother class.
@synthesize roomDisplayname;

- (void)update
{
    [super update];
    roomDisplayname = self.roomDataSource.room.vectorDisplayname;
    if (!roomDisplayname.length)
    {
        roomDisplayname = NSLocalizedStringFromTable(@"room_displayname_no_title", @"Vector", nil);
    }
}

@end
