/*
 Copyright 2019 New Vector Ltd
 
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

/// Protocol describing a router that wraps a UINavigationController and add convenient completion handlers. Completions are called when a Presentable is removed.
/// Routers are used to be passed between coordinators. They handles only `physical` navigation.
protocol NavigationRouterType: class, Presentable {

    /// Present modally a view controller on the navigation controller
    ///
    /// - Parameter module: The Presentable to present.
    /// - Parameter animated: Specify true to animate the transition.
    func present(_ module: Presentable, animated: Bool)
    
    /// Dismiss presented view controller from navigation controller
    ///
    /// - Parameter animated: Specify true to animate the transition.
    /// - Parameter completion: Animation completion (not the pop completion).
    func dismissModule(animated: Bool, completion: (() -> Void)?)
    
    /// Set root view controller of navigation controller
    ///
    /// - Parameter module: The Presentable to set as root.
    /// - Parameter hideNavigationBar: Specify true to hide the UINavigationBar.
    /// - Parameter animated: Specify true to animate the transition.
    /// - Parameter popCompletion: Completion called when `module` is removed from the navigation stack.
    func setRootModule(_ module: Presentable, hideNavigationBar: Bool, animated: Bool, popCompletion: (() -> Void)?)
    
    /// Pop to root view controller of navigation controller and remove all others
    ///
    /// - Parameter animated: Specify true to animate the transition.
    func popToRootModule(animated: Bool)
    
    /// Pops view controllers until the specified view controller is at the top of the navigation stack
    ///
    /// - Parameter module: The Presentable that should to be at the top of the stack.
    /// - Parameter animated: Specify true to animate the transition.
    func popToModule(_ module: Presentable, animated: Bool)
    
    /// Push a view controller on navigation controller stack
    ///
    /// - Parameter animated: Specify true to animate the transition.
    /// - Parameter popCompletion: Completion called when `module` is removed from the navigation stack.
    func push(_ module: Presentable, animated: Bool, popCompletion: (() -> Void)?)
    
    /// Pop last view controller from navigation controller stack
    ///
    /// - Parameter animated: Specify true to animate the transition.
    func popModule(animated: Bool)
    
    /// Returns the modules that are currently in the navigation stack
    var modules: [Presentable] { get }
}

// `NavigationRouterType` default implementation
extension NavigationRouterType {
    func setRootModule(_ module: Presentable) {
        setRootModule(module, hideNavigationBar: false, animated: false, popCompletion: nil)
    }
    
    func setRootModule(_ module: Presentable, popCompletion: (() -> Void)?) {
        setRootModule(module, hideNavigationBar: false, animated: false, popCompletion: popCompletion)
    }
}
