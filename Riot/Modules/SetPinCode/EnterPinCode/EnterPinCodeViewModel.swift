// File created from ScreenTemplate
// $ createScreen.sh SetPinCode/EnterPinCode EnterPinCode
/*
 Copyright 2020 New Vector Ltd
 
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

import Foundation

final class EnterPinCodeViewModel: EnterPinCodeViewModelType {
    
    // MARK: - Properties
    
    // MARK: Private

    private let session: MXSession?
    private var viewMode: SetPinCoordinatorViewMode
    
    private var firstPin: String = ""
    private var currentPin: String = "" {
        didSet {
            self.viewDelegate?.enterPinCodeViewModel(self, didUpdatePlaceholdersCount: currentPin.count)
        }
    }
    private var numberOfFailuresDuringEnterPIN: Int = 0
    
    // MARK: Public

    weak var viewDelegate: EnterPinCodeViewModelViewDelegate?
    weak var coordinatorDelegate: EnterPinCodeViewModelCoordinatorDelegate?
    private let pinCodePreferences: PinCodePreferences
    
    // MARK: - Setup
    
    init(session: MXSession?, viewMode: SetPinCoordinatorViewMode, pinCodePreferences: PinCodePreferences) {
        self.session = session
        self.viewMode = viewMode
        self.pinCodePreferences = pinCodePreferences
    }
    
    // MARK: - Public
    
    func process(viewAction: EnterPinCodeViewAction) {
        switch viewAction {
        case .loadData:
            self.loadData()
        case .digitPressed(let tag):
            self.digitPressed(tag)
        case .forgotPinPressed:
            self.viewDelegate?.enterPinCodeViewModel(self, didUpdateViewState: .forgotPin)
        case .cancel:
            self.coordinatorDelegate?.enterPinCodeViewModelDidCancel(self)
        case .pinsDontMatchAlertAction:
            //  reset pins
            firstPin.removeAll()
            currentPin.removeAll()
            //  go back to first state
            self.update(viewState: .choosePin)
        case .forgotPinAlertResetAction:
            self.coordinatorDelegate?.enterPinCodeViewModelDidCompleteWithReset(self)
        case .forgotPinAlertCancelAction:
            //  no-op
            break
        }
    }
    
    // MARK: - Private
    
    private func digitPressed(_ tag: Int) {
        if tag == -1 {
            //  delete tapped
            if currentPin.isEmpty {
                return
            } else {
                currentPin.removeLast()
            }
        } else {
            //  a digit tapped
            currentPin += String(tag)
            
            if currentPin.count == pinCodePreferences.numberOfDigits {
                switch viewMode {
                case .setPin:
                    //  choosing pin
                    if firstPin.isEmpty {
                        //  go to next screen
                        firstPin = currentPin
                        currentPin.removeAll()
                        update(viewState: .confirmPin)
                    } else {
                        //  check first and second pins
                        if firstPin == currentPin {
                            //  complete with a little delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.coordinatorDelegate?.enterPinCodeViewModel(self, didCompleteWithPin: self.firstPin)
                            }
                        } else {
                            update(viewState: .pinsDontMatch)
                        }
                    }
                case .unlock, .confirmPinToDeactivate:
                    //  unlocking
                    if currentPin != pinCodePreferences.pin {
                        //  no match
                        numberOfFailuresDuringEnterPIN += 1
                        if numberOfFailuresDuringEnterPIN < pinCodePreferences.allowedNumberOfTrialsBeforeAlert {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.viewDelegate?.enterPinCodeViewModel(self, didUpdateViewState: .wrongPin)
                                self.currentPin.removeAll()
                            }
                        } else {
                            viewDelegate?.enterPinCodeViewModel(self, didUpdateViewState: .wrongPinTooManyTimes)
                            numberOfFailuresDuringEnterPIN = 0
                            currentPin.removeAll()
                        }
                    } else {
                        //  match
                        //  complete with a little delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.coordinatorDelegate?.enterPinCodeViewModelDidComplete(self)
                        }
                    }
                default:
                    break
                }
                return
            }
        }
    }
    
    private func loadData() {
        switch viewMode {
        case .setPin:
            update(viewState: .choosePin)
            self.viewDelegate?.enterPinCodeViewModel(self, didUpdateCancelButtonHidden: pinCodePreferences.forcePinProtection)
        case .unlock:
            update(viewState: .unlock)
        case .confirmPinToDeactivate:
            update(viewState: .confirmPinToDisable)
        default:
            break
        }
    }
    
    private func update(viewState: EnterPinCodeViewState) {
        self.viewDelegate?.enterPinCodeViewModel(self, didUpdateViewState: viewState)
    }
}
