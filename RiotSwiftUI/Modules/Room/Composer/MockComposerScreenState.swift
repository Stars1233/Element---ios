//
// Copyright 2022 New Vector Ltd
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

import Foundation
import SwiftUI
import WysiwygComposer

enum MockComposerScreenState: MockScreenState, CaseIterable {
    case send
    case edit
    case reply
    
    var screenType: Any.Type {
        Composer.self
    }
    
    var screenView: ([Any], AnyView) {
        let viewModel: ComposerViewModel
        
        switch self {
        case .send: viewModel = ComposerViewModel(initialViewState: ComposerViewState())
        case .edit: viewModel = ComposerViewModel(initialViewState: ComposerViewState(sendMode: .edit))
        case .reply: viewModel = ComposerViewModel(initialViewState: ComposerViewState(eventSenderDisplayName: "TestUser", sendMode: .reply))
        }
        
        let wysiwygviewModel = WysiwygComposerViewModel(minHeight: 20, maxHeight: 360)
        
        viewModel.callback = { [weak viewModel, weak wysiwygviewModel] result in
            guard let viewModel = viewModel else { return }
            if viewModel.sendMode == .edit {
                wysiwygviewModel?.setHtmlContent("")
            }
            switch result {
            case .cancel: viewModel.sendMode = .send
            }
        }
        
        return (
            [viewModel, wysiwygviewModel],
            AnyView(VStack {
                Spacer()
                Composer(viewModel: viewModel.context, wysiwygViewModel: wysiwygviewModel, sendMessageAction: { _ in }, showSendMediaActions: { })
            }.frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .topLeading
            ))
        )
    }
}
