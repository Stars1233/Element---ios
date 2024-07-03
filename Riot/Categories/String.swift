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

import Foundation

extension String {
    
    /// Calculates a numeric hash same as Riot Web
    /// See original function here https://github.com/matrix-org/matrix-react-sdk/blob/321dd49db4fbe360fc2ff109ac117305c955b061/src/utils/FormattingUtils.js#L47
    var vc_hashCode: Int32 {
        var hash: Int32 = 0
        
        for character in self {
            let shiftedHash = hash << 5
            hash = shiftedHash.subtractingReportingOverflow(hash).partialValue + Int32(character.vc_unicodeScalarCodePoint)
        }
        return abs(hash)
    }
    
    /// Locale-independent case-insensitive contains
    /// Note: Prefer use `localizedCaseInsensitiveContains` when locale matters
    ///
    /// - Parameter other: The other string.
    /// - Returns: true if current string contains other string.
    func vc_caseInsensitiveContains(_ other: String) -> Bool {
        return self.range(of: other, options: .caseInsensitive) != nil
    }
}
