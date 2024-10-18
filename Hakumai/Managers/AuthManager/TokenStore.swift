//
//  TokenStore.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/27.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import SAMKeychain

protocol TokenStoreProtocol {
    func saveToken(_ storedToken: StoredToken)
    func loadToken() -> StoredToken?
    func clearToken()
}

struct StoredToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let refreshToken: String
    let idToken: String?
}

private let keychainAccountName = "token"

final class TokenStore: TokenStoreProtocol {}

extension TokenStore {
    func saveToken(_ storedToken: StoredToken) {
        guard let encoded = try? JSONEncoder().encode(storedToken) else { return }
        let jsonString = String(decoding: encoded, as: UTF8.self)
        log.debug(jsonString)
        let success = SAMKeychain.setPassword(
            jsonString,
            forService: TokenStore.keychainServiceName,
            account: keychainAccountName
        )
        if !success {
            log.error("Failed to save the token to keychain.")
        }
    }

    func loadToken() -> StoredToken? {
        guard let jsonString = SAMKeychain.password(
                forService: TokenStore.keychainServiceName,
                account: keychainAccountName),
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    func clearToken() {
        SAMKeychain.deletePassword(
            forService: TokenStore.keychainServiceName,
            account: keychainAccountName
        )
    }
}

private extension TokenStore {
    static var keychainServiceName: String = {
        (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? "") + ".token"
    }()
}
