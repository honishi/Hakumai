//
//  AuthManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/21.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol AuthManagerProtocol {
    func extractCallbackResponseAndSaveToken(response: String, completion: ((Result<Void, AuthManagerError>) -> Void))
    func refreshToken(completion: ((Result<Void, AuthManagerError>) -> Void))
}

enum AuthManagerError: Error {
    case decode
}

extension AuthManager {
    static let shared = AuthManager()
}

final class AuthManager: AuthManagerProtocol {
    // MARK: Types
    struct Token {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int
        let scope: String
        let refreshToken: String
        let idToken: String
    }

    // MARK: Properties
    private var currentToken: Token?

    init() {}
}

extension AuthManager {
    func extractCallbackResponseAndSaveToken(response: String, completion: ((Result<Void, AuthManagerError>) -> Void)) {
        guard let data = response.data(using: .utf8) else {
            completion(.failure(.decode))
            return
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let tokenResponse = try? decoder.decode(TokenResponse.self, from: data) else {
            completion(.failure(.decode))
            return
        }
        log.debug(tokenResponse)
        saveToken(from: tokenResponse)
        completion(.success(()))
    }

    func refreshToken(completion: ((Result<Void, AuthManagerError>) -> Void)) {
        // TODO: call token endpoint
    }
}

private extension AuthManager {
    func saveToken(from response: TokenResponse) {
        currentToken = Token(
            accessToken: response.accessToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            scope: response.scope,
            refreshToken: response.refreshToken,
            idToken: response.idToken
        )
        // TODO: save to keychain
    }
}
