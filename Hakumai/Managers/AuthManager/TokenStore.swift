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

final class TokenStore: TokenStoreProtocol {
    private var _store: String?

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
        guard let encoded = try? JSONEncoder().encode(storedToken) else { return }
        // TODO: save to keychain
        _store = String(data: encoded, encoding: .utf8)
        log.debug(_store)
    }
    // swiftlint:enable function_parameter_count

    func loadToken() -> StoredToken? {
        // TODO: load from keychain
        guard let storedToken = _store,
              let data = storedToken.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    func clearToken() {
        _store = nil
    }
}
