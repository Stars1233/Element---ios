// 
// Copyright 2020 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit
import Reusable

final class RoomAvatarView: AvatarView, NibOwnerLoadable {
    
    // MARK: - Properties

    // MARK: Outlets
    
    @IBOutlet private weak var cameraBadgeContainerView: UIView!
    
    // MARK: Public
    
    var showCameraBadgeOnFallbackImage: Bool = false
    
    // MARK: - Setup
    
    private func commonInit() {
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadNibContent()
        self.commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadNibContent()
        self.commonInit()
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.avatarImageView.layer.cornerRadius = self.avatarImageView.bounds.height/2
    }
    
    // MARK: - Public
    
    override func fill(with viewData: AvatarViewDataProtocol) {
        self.updateAvatarImageView(with: viewData)

        // Fix layoutSubviews not triggered issue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setNeedsLayout()
        }
    }
    
    // MARK: - Overrides
    
    override func updateAccessibilityTraits() {
        if self.isUserInteractionEnabled {
            self.vc_setupAccessibilityTraitsButton(withTitle: VectorL10n.roomAvatarViewAccessibilityLabel, hint: VectorL10n.roomAvatarViewAccessibilityHint, isEnabled: true)
        } else {
            self.vc_setupAccessibilityTraitsImage(withTitle: VectorL10n.roomAvatarViewAccessibilityLabel)
        }
    }
    
    override func updateAvatarImageView(with viewData: AvatarViewDataProtocol) {
        super.updateAvatarImageView(with: viewData)
        
        let hideCameraBadge: Bool
        
        if self.showCameraBadgeOnFallbackImage {
            hideCameraBadge = viewData.avatarUrl != nil
        } else {
            hideCameraBadge = true
        }
        
        self.cameraBadgeContainerView.isHidden = hideCameraBadge
    }
}
