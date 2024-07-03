// File created from FlowTemplate
// $ createRootCoordinator.sh KeyBackupSetup/SecureSetup SecureKeyBackupSetup
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

import UIKit

@objcMembers
final class SecureBackupSetupCoordinator: SecureBackupSetupCoordinatorType {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private let navigationRouter: NavigationRouterType
    private let session: MXSession
    private let recoveryService: MXRecoveryService
    private let keyBackup: MXKeyBackup?

    // MARK: Public

    // Must be used only internally
    var childCoordinators: [Coordinator] = []
    
    weak var delegate: SecureBackupSetupCoordinatorDelegate?
    
    // MARK: - Setup
    
    init(session: MXSession) {
        self.navigationRouter = NavigationRouter(navigationController: RiotNavigationController())
        self.session = session
        self.recoveryService = session.crypto.recoveryService
        self.keyBackup = session.crypto.backup
    }    
    
    // MARK: - Public methods
    
    func start() {
        let rootViewController = self.createIntro()
        self.navigationRouter.setRootModule(rootViewController)
    }
    
    func toPresentable() -> UIViewController {
        return self.navigationRouter.toPresentable()
    }
    
    // MARK: - Private methods

    private func createIntro() -> SecureBackupSetupIntroViewController {
        let introViewController = SecureBackupSetupIntroViewController.instantiate()
        introViewController.delegate = self
        introViewController.keyBackup = self.keyBackup
        return introViewController
    }
    
    private func showSetupKey(passphrase: String? = nil) {
        let coordinator = SecretsSetupRecoveryKeyCoordinator(recoveryService: self.recoveryService, passphrase: passphrase)
        coordinator.delegate = self
        coordinator.start()
        
        self.add(childCoordinator: coordinator)
        self.navigationRouter.push(coordinator, animated: true) { [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    private func showSetupPassphrase() {
        let coordinator = SecretsSetupRecoveryPassphraseCoordinator(passphraseInput: .new)
        coordinator.delegate = self
        coordinator.start()

        self.add(childCoordinator: coordinator)
        self.navigationRouter.push(coordinator, animated: true) { [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    private func showSetupPassphraseConfirmation(with passphrase: String) {
        let coordinator = SecretsSetupRecoveryPassphraseCoordinator(passphraseInput: .confirm(passphrase))
        coordinator.delegate = self
        coordinator.start()
        
        self.add(childCoordinator: coordinator)
        self.navigationRouter.push(coordinator, animated: true) { [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    private func showCancelAlert() {
        let alertController = UIAlertController(title: VectorL10n.secureKeyBackupSetupCancelAlertTitle,
                                                message: VectorL10n.secureKeyBackupSetupCancelAlertMessage,
                                                preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: VectorL10n.continue, style: .cancel, handler: { action in
        }))
        
        alertController.addAction(UIAlertAction(title: VectorL10n.keyBackupSetupSkipAlertSkipAction, style: .default, handler: { action in
            self.delegate?.secureBackupSetupCoordinatorDidCancel(self)
        }))
        
        self.navigationRouter.present(alertController, animated: true)
    }
    
    private func showKeyBackupRestore() {
        guard let keyBackupVersion = self.keyBackup?.keyBackupVersion else {
            return
        }
        
        let coordinator = KeyBackupRecoverCoordinator(session: self.session, keyBackupVersion: keyBackupVersion, navigationRouter: self.navigationRouter)
        
        self.add(childCoordinator: coordinator)
        coordinator.delegate = self
        coordinator.start() // Will trigger view controller push
    }
    
    private func didCancel(showSkipAlert: Bool = true) {
        if showSkipAlert {
            self.showCancelAlert()
        } else {
            self.delegate?.secureBackupSetupCoordinatorDidCancel(self)
        }
    }
    
    private func didComplete() {
        self.delegate?.secureBackupSetupCoordinatorDidComplete(self)
    }
}

// MARK: - SecureBackupSetupIntroViewControllerDelegate
extension SecureBackupSetupCoordinator: SecureBackupSetupIntroViewControllerDelegate {
    
    func secureBackupSetupIntroViewControllerDidTapUseKey(_ secureBackupSetupIntroViewController: SecureBackupSetupIntroViewController) {
        self.showSetupKey()
    }
    
    func secureBackupSetupIntroViewControllerDidTapUsePassphrase(_ secureBackupSetupIntroViewController: SecureBackupSetupIntroViewController) {
        self.showSetupPassphrase()
    }
    
    func secureBackupSetupIntroViewControllerDidCancel(_ secureBackupSetupIntroViewController: SecureBackupSetupIntroViewController, showSkipAlert: Bool) {
        self.didCancel(showSkipAlert: showSkipAlert)
    }
    
    func secureBackupSetupIntroViewControllerDidTapConnectToKeyBackup(_ secureBackupSetupIntroViewController: SecureBackupSetupIntroViewController) {
        self.showKeyBackupRestore()
    }
}

// MARK: - SecretsSetupRecoveryKeyCoordinatorDelegate
extension SecureBackupSetupCoordinator: SecretsSetupRecoveryKeyCoordinatorDelegate {
    
    func secretsSetupRecoveryKeyCoordinatorDidComplete(_ coordinator: SecretsSetupRecoveryKeyCoordinatorType) {
        self.didComplete()
    }
    
    func secretsSetupRecoveryKeyCoordinatorDidFailed(_ coordinator: SecretsSetupRecoveryKeyCoordinatorType) {
        self.didCancel(showSkipAlert: false)
    }
    
    func secretsSetupRecoveryKeyCoordinatorDidCancel(_ coordinator: SecretsSetupRecoveryKeyCoordinatorType) {
        self.didCancel()
    }
}

// MARK: - SecretsSetupRecoveryPassphraseCoordinatorDelegate
extension SecureBackupSetupCoordinator: SecretsSetupRecoveryPassphraseCoordinatorDelegate {
    
    func secretsSetupRecoveryPassphraseCoordinator(_ coordinator: SecretsSetupRecoveryPassphraseCoordinatorType, didEnterNewPassphrase passphrase: String) {
        self.showSetupPassphraseConfirmation(with: passphrase)
    }
    
    func secretsSetupRecoveryPassphraseCoordinator(_ coordinator: SecretsSetupRecoveryPassphraseCoordinatorType, didConfirmPassphrase passphrase: String) {
        self.showSetupKey(passphrase: passphrase)
    }
    
    func secretsSetupRecoveryPassphraseCoordinatorDidCancel(_ coordinator: SecretsSetupRecoveryPassphraseCoordinatorType) {
        self.didCancel()
    }
}

// MARK: - KeyBackupRecoverCoordinatorDelegate
extension SecureBackupSetupCoordinator: KeyBackupRecoverCoordinatorDelegate {
    func keyBackupRecoverCoordinatorDidCancel(_ keyBackupRecoverCoordinator: KeyBackupRecoverCoordinatorType) {
        self.navigationRouter.popToRootModule(animated: true)
    }
    
    func keyBackupRecoverCoordinatorDidRecover(_ keyBackupRecoverCoordinator: KeyBackupRecoverCoordinatorType) {
        self.navigationRouter.popToRootModule(animated: true)
    }
}
