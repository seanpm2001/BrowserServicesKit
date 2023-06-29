//
//  LoginsProvider.swift
//  DuckDuckGo
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
import BrowserServicesKit
import Combine
import DDGSync

public final class LoginsProvider: DataProviding {

    public init(secureVaultFactory: SecureVaultFactory = .default, metadataStore: SyncMetadataStore, reloadLoginsAfterSync: @escaping () -> Void) throws {
        self.secureVaultFactory = secureVaultFactory
        self.metadataStore = metadataStore
        try self.metadataStore.registerFeature(named: feature.name)
        self.reloadLoginsAfterSync = reloadLoginsAfterSync
        syncErrorPublisher = syncErrorSubject.eraseToAnyPublisher()
    }

    public let syncErrorPublisher: AnyPublisher<Error, Never>

    // MARK: - DataProviding

    public let feature: Feature = .init(name: "logins")

    public var lastSyncTimestamp: String? {
        get {
            metadataStore.timestamp(forFeatureNamed: feature.name)
        }
        set {
            metadataStore.updateTimestamp(newValue, forFeatureNamed: feature.name)
        }
    }

    public func prepareForFirstSync() throws {
        lastSyncTimestamp = nil
    }

    public func fetchChangedObjects(encryptedUsing crypter: Crypting) async throws -> [Syncable] {
        []
    }

    public func handleInitialSyncResponse(received: [Syncable], clientTimestamp: Date, serverTimestamp: String?, crypter: Crypting) async throws {
    }

    public func handleSyncResponse(sent: [Syncable], received: [Syncable], clientTimestamp: Date, serverTimestamp: String?, crypter: Crypting) async throws {
    }

    public func handleSyncError(_ error: Error) {
        syncErrorSubject.send(error)
    }


    // MARK: - Private

    private let secureVaultFactory: SecureVaultFactory
    private let metadataStore: SyncMetadataStore
    private let reloadLoginsAfterSync: () -> Void
    private let syncErrorSubject = PassthroughSubject<Error, Never>()

    // MARK: - Test support

#if DEBUG
    var willSaveContextAfterApplyingSyncResponse: () -> Void = {}
#endif

}