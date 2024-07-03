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

#import "DirectoryRecentTableViewCell.h"

#import "PublicRoomsDirectoryDataSource.h"

@implementation DirectoryRecentTableViewCell

#pragma mark - Class methods

- (void)render:(PublicRoomsDirectoryDataSource *)publicRoomsDirectoryDataSource
{
    self.userInteractionEnabled = NO;
    self.chevronImageView.hidden = YES;

    // Show information according to the data source state
    switch (publicRoomsDirectoryDataSource.state)
    {
        case MXKDataSourceStatePreparing:
            self.titleLabel.text = NSLocalizedStringFromTable(@"directory_searching_title", @"Vector", nil);
            self.descriptionLabel.text = @"";
            break;

        case MXKDataSourceStateReady:
        {
            // Concatenate all patterns into one string
            NSString *filter = [publicRoomsDirectoryDataSource.searchPatternsList componentsJoinedByString:@" "];

            self.titleLabel.text = NSLocalizedStringFromTable(@"directory_search_results_title", @"Vector", nil);
            self.descriptionLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"directory_search_results", @"Vector", nil),
                                          publicRoomsDirectoryDataSource.filteredRooms.count,
                                          filter];

            if (publicRoomsDirectoryDataSource.filteredRooms.count)
            {
                self.userInteractionEnabled = YES;
                self.chevronImageView.hidden = NO;
            }
            break;
        }

        case MXKDataSourceStateFailed:
            self.titleLabel.text = NSLocalizedStringFromTable(@"directory_searching_title", @"Vector", nil);
            self.descriptionLabel.text = NSLocalizedStringFromTable(@"directory_search_fail", @"Vector", nil);
            break;

        default:
            break;
    }
}

+ (CGFloat)cellHeight
{
    return 74;
}

@end
