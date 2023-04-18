//
//  SyncRequestMaker.swift
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

protocol SyncRequestMaking {
    func makeGetRequest(for features: [Feature]) throws -> HTTPRequesting
    func makePatchRequest(with results: [Feature: ResultsProvider]) throws -> HTTPRequesting
}

struct SyncRequestMaker: SyncRequestMaking {
    let storage: SecureStoring
    let api: RemoteAPIRequestCreating 
    let endpoints: Endpoints


    func makeGetRequest(for features: [Feature]) throws -> HTTPRequesting {
        let url = try endpoints.syncGet(features: features.map(\.name))
        return api.createRequest(
            url: url,
            method: .GET,
            headers: ["Authorization": "Bearer \(try getToken())"],
            parameters: [:],
            body: nil,
            contentType: nil
        )
    } 

    func makePatchRequest(with results: [Feature: ResultsProvider]) throws -> HTTPRequesting {
        var json = [String: Any]()
        for (feature, result) in results {
            let modelPayload: [String: Any?] = [
                "updates": result.sent.map(\.payload),
                "modified_since": result.previousSyncTimestamp
            ]
            json[feature.name] = modelPayload
        }

        let body = try JSONSerialization.data(withJSONObject: json, options: [])
        return api.createRequest(
            url: endpoints.syncPatch,
            method: .PATCH,
            headers: ["Authorization": "Bearer \(try getToken())"],
            parameters: [:],
            body: body,
            contentType: "application/json"
        )
    }

    private func getToken() throws -> String {
        guard let account = try storage.account() else {
            throw SyncError.accountNotFound
        }

        guard let token = account.token else {
            throw SyncError.noToken
        }

        return token
    }
}