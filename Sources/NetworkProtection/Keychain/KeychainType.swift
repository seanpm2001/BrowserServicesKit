//
//  KeychainType.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// A convenience enum to unify the logic for selecting the right keychain through the query attributes.
///
public enum KeychainType {
    /// Uses the system keychain.
    ///
    case system

    /// Uses the data protection keychain for the specified access group (to which the app must have access to).
    ///
    case accessGroup(_ accessGroup: AccessGroup)

    public enum AccessGroup {
        case any
        case named(_ name: String)
    }

    func queryAttributes() -> [CFString: Any] {
        switch self {
        case .system:
            return [kSecUseDataProtectionKeychain: false]
        case .accessGroup(let accessGroup):
            switch accessGroup {
            case .any:
                return [kSecUseDataProtectionKeychain: true]
            case .named(let accessGroup):
                return [
                    kSecUseDataProtectionKeychain: true,
                    kSecAttrAccessGroup: accessGroup
                ]
            }
        }
    }
}
