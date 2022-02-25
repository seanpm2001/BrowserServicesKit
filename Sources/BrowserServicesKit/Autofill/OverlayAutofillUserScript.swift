//
//  OverlayAutofillUserScript.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

/// Handles calls from the top Autofill context to the overlay
public protocol OverlayAutofillUserScriptToOverlayDelegate: AnyObject {
    /// Provides a size that the overlay should be resized to
    func overlayAutofillUserScript(_ overlayAutofillUserScript: OverlayAutofillUserScript, requestResizeToSize: CGFloat, height: CGFloat)
}

public class OverlayAutofillUserScript: AutofillUserScript {

    public var contentOverlay: OverlayAutofillUserScriptToOverlayDelegate?
    /// Used as a message channel from parent WebView to the relevant in page AutofillUserScript.
    public var websiteAutofillInstance: AutofillMessagingToChildDelegate?

    internal enum OverlayAutofillMessageName: String, CaseIterable {
        case setSize
        case selectedDetail
        case closeAutofillParent
    }

    public override var messageNames: [String] {
        return OverlayAutofillMessageName.allCases.map(\.rawValue) + super.messageNames
    }

    internal override func messageHandlerFor(_ messageName: String) -> MessageHandler? {
        guard let overlayAutofillMessage = OverlayAutofillMessageName(rawValue: messageName) else {
            return super.messageHandlerFor(messageName)
        }

        switch overlayAutofillMessage {
        case .setSize: return setSize
        case .selectedDetail: return selectedDetail
        case .closeAutofillParent: return closeAutofillParent
        }
    }

    override func hostForMessage(_ message: AutofillMessage) -> String {
        return websiteAutofillInstance?.overlayAutofillUserScriptLastOpenHost ?? ""
    }

    func closeAutofillParent(_ message: AutofillMessage, _ replyHandler: MessageReplyHandler) {
        guard let websiteAutofillInstance = websiteAutofillInstance else { return }
        self.contentOverlay?.overlayAutofillUserScript(self, requestResizeToSize: 0, height: 0)
        websiteAutofillInstance.overlayAutofillUserScriptClose(self)
        replyHandler(nil)
    }

    /// Used to create a top autofill context script for injecting into a ContentOverlay
    public convenience init(scriptSourceProvider: AutofillUserScriptSourceProvider, overlay: OverlayAutofillUserScriptToOverlayDelegate) {
        self.init(scriptSourceProvider: scriptSourceProvider, encrypter: AESGCMAutofillEncrypter(), hostProvider: SecurityOriginHostProvider())
        self.isTopAutofillContext = true
        self.contentOverlay = overlay
    }

    func setSize(_ message: AutofillMessage, _ replyHandler: MessageReplyHandler) {
        guard let dict = message.messageBody as? [String: Any],
              let width = dict["width"] as? CGFloat,
              let height = dict["height"] as? CGFloat else {
                  return replyHandler(nil)
              }
        self.contentOverlay?.overlayAutofillUserScript(self, requestResizeToSize: width, height: height)
        replyHandler(nil)
    }

    /// Called from top autofill messages and stores the details the user clicked on into the child autofill
    func selectedDetail(_ message: AutofillMessage, _ replyHandler: @escaping MessageReplyHandler) {
        guard let dict = message.messageBody as? [String: Any],
              let chosenCredential = dict["data"] as? [String: String],
              let configType = dict["configType"] as? String,
              let autofillInterfaceToChild = websiteAutofillInstance else { return }
        autofillInterfaceToChild.overlayAutofillUserScript(self, messageSelectedCredential: chosenCredential, configType)
    }

}
