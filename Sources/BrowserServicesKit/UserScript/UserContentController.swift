//
//  UserContentController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import WebKit
import Combine

public protocol UserContentControllerDelegate: AnyObject {
    func userContentController(_ userContentController: UserContentController,
                               didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList],
                               userScripts: UserScriptsProvider,
                               updateEvent: ContentBlockerRulesManager.UpdateEvent)
}

final public class UserContentController: WKUserContentController {
    let privacyConfigurationManager: PrivacyConfigurationManager
    public weak var delegate: UserContentControllerDelegate?

    public struct ContentBlockingAssets {
        public let contentRuleLists: [String: WKContentRuleList]
        public let userScripts: UserScriptsProvider
        public let updateEvent: ContentBlockerRulesManager.UpdateEvent

        public init(contentRuleLists: [String : WKContentRuleList],
                    userScripts: UserScriptsProvider,
                    updateEvent: ContentBlockerRulesManager.UpdateEvent) {
            self.contentRuleLists = contentRuleLists
            self.userScripts = userScripts
            self.updateEvent = updateEvent
        }
    }
    @Published public private(set) var contentBlockingAssets: ContentBlockingAssets? {
        willSet {
            self.removeAllContentRuleLists()
            self.removeAllUserScripts()
        }
        didSet {
            guard let contentBlockingAssets = contentBlockingAssets else { return }
            self.installContentRuleLists(contentBlockingAssets.contentRuleLists)
            self.installUserScripts(contentBlockingAssets.userScripts)

            delegate?.userContentController(self,
                                            didInstallContentRuleLists: contentBlockingAssets.contentRuleLists,
                                            userScripts: contentBlockingAssets.userScripts,
                                            updateEvent: contentBlockingAssets.updateEvent)
        }
    }

    private var cancellable: AnyCancellable?

    public init<Pub: Publisher>(assetsPublisher: Pub, privacyConfigurationManager: PrivacyConfigurationManager)
    where Pub.Failure == Never, Pub.Output == ContentBlockingAssets {

        self.privacyConfigurationManager = privacyConfigurationManager
        super.init()

        cancellable = assetsPublisher.receive(on: DispatchQueue.main).map { $0 }.assign(to: \.contentBlockingAssets, on: self) // TODO: onWeaklyHeld

#if DEBUG
        // make sure delegate for UserScripts is set shortly after init
        DispatchQueue.main.async { [weak self] in
            assert(self == nil || self?.delegate != nil, "UserContentController delegate not set")
        }
#endif
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func installContentRuleLists(_ contentRuleLists: [String: WKContentRuleList]) {
        guard self.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) else { return }

        contentRuleLists.values.forEach(self.add)
    }

    public struct ContentRulesNotFoundError: Error {}
    public func enableContentRuleList(withIdentifier identifier: String) throws {
        guard let ruleList = self.contentBlockingAssets?.contentRuleLists[identifier] else {
            throw ContentRulesNotFoundError()
        }
        self.add(ruleList)
    }

    public func disableContentRuleList(withIdentifier identifier: String) {
        guard let ruleList = self.contentBlockingAssets?.contentRuleLists[identifier] else {
            assertionFailure("Rule list not installed")
            return
        }
        self.remove(ruleList)
    }

    private func installUserScripts(_ userScripts: UserScriptsProvider) {
        userScripts.scripts.forEach(self.addUserScript)
        userScripts.userScripts.forEach(self.addHandler)
    }

    public override func removeAllUserScripts() {
        super.removeAllUserScripts()
        self.contentBlockingAssets?.userScripts.userScripts.forEach(self.removeHandler)
    }

    func addHandlerNoContentWorld(_ userScript: UserScript) {
        for messageName in userScript.messageNames {
            add(userScript, name: messageName)
        }
    }

    func addHandler(_ userScript: UserScript) {
        for messageName in userScript.messageNames {
            if #available(macOS 11.0, iOS 14.0, *) {
                let contentWorld: WKContentWorld = userScript.getContentWorld()
                if let handlerWithReply = userScript as? WKScriptMessageHandlerWithReply {
                    addScriptMessageHandler(handlerWithReply, contentWorld: contentWorld, name: messageName)
                } else {
                    add(userScript, contentWorld: contentWorld, name: messageName)
                }
            } else {
                add(userScript, name: messageName)
            }
        }
    }

    func removeHandler(_ userScript: UserScript) {
        userScript.messageNames.forEach {
            if #available(macOS 11.0, iOS 14.0, *) {
                let contentWorld: WKContentWorld = userScript.getContentWorld()
                removeScriptMessageHandler(forName: $0, contentWorld: contentWorld)
            } else {
                removeScriptMessageHandler(forName: $0)
            }
        }
    }

}

public extension UserContentController {

    var contentBlockingAssetsInstalled: Bool {
        contentBlockingAssets != nil
    }

    @MainActor
    func awaitContentBlockingAssetsInstalled() async {
        guard !contentBlockingAssetsInstalled else { return }

        await withCheckedContinuation { c in
            var cancellable: AnyCancellable!
            cancellable = $contentBlockingAssets.receive(on: DispatchQueue.main).sink { assets in
                guard assets != nil else { return }
                withExtendedLifetime(cancellable) {
                    c.resume()
                    cancellable.cancel()
                }
            }
        } as Void
    }

}