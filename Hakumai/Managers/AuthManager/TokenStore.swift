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
    // swiftlint:disable function_parameter_count
    func saveToken(accessToken: String, tokenType: String, expiresIn: Int, scope: String, refreshToken: String, idToken: String?)
    // swiftlint:enable function_parameter_count
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
    // swiftlint:disable function_parameter_count
    func saveToken(accessToken: String, tokenType: String, expiresIn: Int, scope: String, refreshToken: String, idToken: String?) {
        let storedToken = StoredToken(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            refreshToken: refreshToken,
            idToken: idToken
        )
        guard let encoded = try? JSONEncoder().encode(storedToken),
              let jsonString = String(data: encoded, encoding: .utf8) else { return }
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
    // swiftlint:enable function_parameter_count

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
