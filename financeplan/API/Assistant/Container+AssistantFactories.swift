//
//  Container+AssistantFactories.swift
//  financeplan
//

import Factory
import Foundation

extension Container {
    var assistantStreamClient: Factory<AssistantStreamClient> {
        self { @MainActor [unowned self] in
            let env = self.appEnvironment()
            let store = self.authSessionStore()
            return AssistantStreamClient(
                baseURL: env.current.apiBaseUrl,
                session: URLSession.shared,
                authTokenProvider: { await store.authToken }
            )
        }
    }
}
