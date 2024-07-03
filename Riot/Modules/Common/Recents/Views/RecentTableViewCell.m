/*
 Copyright 2015 OpenMarket Ltd
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

#import "RecentTableViewCell.h"

#import "AvatarGenerator.h"

#import "MXEvent.h"
#import "MXRoom+Riot.h"

#import "ThemeService.h"
#import "Riot-Swift.h"

#import "MXRoomSummary+Riot.h"

#pragma mark - Defines & Constants

static const CGFloat kDirectRoomBorderColorAlpha = 0.75;
static const CGFloat kDirectRoomBorderWidth = 3.0;

@implementation RecentTableViewCell

#pragma mark - Class methods

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Initialize unread count badge
    [_missedNotifAndUnreadBadgeBgView.layer setCornerRadius:10];
    _missedNotifAndUnreadBadgeBgViewWidthConstraint.constant = 0;
}

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    self.roomTitle.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.lastEventDescription.textColor = ThemeService.shared.theme.textSecondaryColor;
    self.lastEventDate.textColor = ThemeService.shared.theme.textSecondaryColor;
    self.missedNotifAndUnreadBadgeLabel.textColor = ThemeService.shared.theme.baseTextPrimaryColor;
    
    // Prepare direct room border
    CGColorRef directRoomBorderColor = CGColorCreateCopyWithAlpha(ThemeService.shared.theme.tintColor.CGColor, kDirectRoomBorderColorAlpha);
    
    [self.directRoomBorderView.layer setCornerRadius:self.directRoomBorderView.frame.size.width / 2];
    self.directRoomBorderView.clipsToBounds = YES;
    self.directRoomBorderView.layer.borderColor = directRoomBorderColor;
    self.directRoomBorderView.layer.borderWidth = kDirectRoomBorderWidth;
    
    CFRelease(directRoomBorderColor);
    
    self.roomAvatar.defaultBackgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Round image view
    [_roomAvatar.layer setCornerRadius:_roomAvatar.frame.size.width / 2];
    _roomAvatar.clipsToBounds = YES;
}

- (void)render:(MXKCellData *)cellData
{
    // Hide by default missed notifications and unread widgets
    self.missedNotifAndUnreadIndicator.hidden = YES;
    self.missedNotifAndUnreadBadgeBgView.hidden = YES;
    self.missedNotifAndUnreadBadgeBgViewWidthConstraint.constant = 0;
    
    roomCellData = (id<MXKRecentCellDataStoring>)cellData;
    if (roomCellData)
    {
        // Report computed values as is
        self.roomTitle.text = roomCellData.roomDisplayname;
        self.lastEventDate.text = roomCellData.lastEventDate;
        
        // Manage lastEventAttributedTextMessage optional property
        if ([roomCellData respondsToSelector:@selector(lastEventAttributedTextMessage)])
        {
            // Force the default text color for the last message (cancel highlighted message color)
            NSMutableAttributedString *lastEventDescription = [[NSMutableAttributedString alloc] initWithAttributedString:roomCellData.lastEventAttributedTextMessage];
            [lastEventDescription addAttribute:NSForegroundColorAttributeName value:ThemeService.shared.theme.textSecondaryColor range:NSMakeRange(0, lastEventDescription.length)];
            self.lastEventDescription.attributedText = lastEventDescription;
        }
        else
        {
            self.lastEventDescription.text = roomCellData.lastEventTextMessage;
        }
        
        self.unsentImageView.hidden = roomCellData.roomSummary.room.sentStatus == RoomSentStatusOk;
        self.lastEventDecriptionLabelTrailingConstraint.constant = self.unsentImageView.hidden ? 10 : 30;

        // Notify unreads and bing
        if (roomCellData.hasUnread)
        {
            self.missedNotifAndUnreadIndicator.hidden = NO;
            
            if (0 < roomCellData.notificationCount)
            {
                self.missedNotifAndUnreadIndicator.backgroundColor = roomCellData.highlightCount ? ThemeService.shared.theme.noticeColor : ThemeService.shared.theme.noticeSecondaryColor;
                
                self.missedNotifAndUnreadBadgeBgView.hidden = NO;
                self.missedNotifAndUnreadBadgeBgView.backgroundColor = self.missedNotifAndUnreadIndicator.backgroundColor;
                
                self.missedNotifAndUnreadBadgeLabel.text = roomCellData.notificationCountStringValue;
                [self.missedNotifAndUnreadBadgeLabel sizeToFit];
                
                self.missedNotifAndUnreadBadgeBgViewWidthConstraint.constant = self.missedNotifAndUnreadBadgeLabel.frame.size.width + 18;
            }
            else
            {
                self.missedNotifAndUnreadIndicator.backgroundColor = ThemeService.shared.theme.unreadRoomIndentColor;
            }
            
            // Use bold font for the room title
            self.roomTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        }
        else
        {
            self.lastEventDate.textColor = ThemeService.shared.theme.textSecondaryColor;
            
            // The room title is not bold anymore            
            self.roomTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        }
        
        self.directRoomBorderView.hidden = !roomCellData.roomSummary.room.isDirect;

        [roomCellData.roomSummary setRoomAvatarImageIn:self.roomAvatar];
    }
    else
    {
        self.lastEventDescription.text = @"";
    }
}

+ (CGFloat)heightForCellData:(MXKCellData *)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // The height is fixed
    return 74;
}

@end
