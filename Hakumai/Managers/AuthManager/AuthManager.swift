//
//  AuthManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/21.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

private let hakumaiServerApiBaseUrl = "https://hakumai-app.com"
private let hakumaiServerApiPathRefreshToken = "/api/v1/refresh-token"

protocol AuthManagerProtocol {
    func extractCallbackResponseAndSaveToken(response: String, completion: ((Result<Void, AuthManagerError>) -> Void))
    func refreshToken(completion: @escaping ((Result<Void, AuthManagerError>) -> Void))
}

enum AuthManagerError: Error {
    case noAvailableRefreshToken
    case refreshTokenFailed
    case decode
    case `internal`
}

extension AuthManager {
    static let shared = AuthManager(tokenStore: TokenStore())
}

final class AuthManager: AuthManagerProtocol {
    // MARK: Types
    struct Token: Codable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int
        let scope: String
        let refreshToken: String
        let idToken: String?
    }

    // MARK: Properties
    private let tokenStore: TokenStoreProtocol
    private var currentToken: Token?

    init(tokenStore: TokenStoreProtocol) {
        self.tokenStore = tokenStore
        currentToken = loadToken()
    }
}

extension AuthManager {
    func extractCallbackResponseAndSaveToken(response: String, completion: ((Result<Void, AuthManagerError>) -> Void)) {
        guard let tokenResponse = decodeTokenResponse(from: response) else {
            completion(.failure(.decode))
            return
        }
        log.debug(tokenResponse)
        saveToken(from: tokenResponse)
        completion(.success(()))
    }

    func refreshToken(completion: @escaping ((Result<Void, AuthManagerError>) -> Void)) {
        guard let refreshToken = currentToken?.refreshToken else {
            completion(.failure(.noAvailableRefreshToken))
            return
        }
        guard let url = URL(string: hakumaiServerApiBaseUrl + hakumaiServerApiPathRefreshToken) else {
            completion(.failure(.internal))
            return
        }
        var request = URLRequest(url: url)
        request.method = .post
        request.httpBody = "refresh_token=\(refreshToken)".data(using: .utf8)
        AF.request(request)
            .cURLDescription { log.debug($0) }
            .validate()
            .responseString { [weak self] in
                guard let me = self else { return }
                // log.debug($0)
                switch $0.result {
                case .success(let string):
                    log.debug(string)
                    guard let tokenResponse = me.decodeTokenResponse(from: string) else {
                        completion(.failure(.decode))
                        return
                    }
                    me.saveToken(from: tokenResponse)
                    completion(.success(()))
                case .failure(let error):
                    log.error(error)
                    completion(.failure(.refreshTokenFailed))
                }
            }
    }
}

private extension AuthManager {
    func decodeTokenResponse(from string: String) -> TokenResponse? {
        guard let data = string.data(using: .utf8) else { return nil }
        return decodeTokenResponse(from: data)
    }

    func decodeTokenResponse(from data: Data) -> TokenResponse? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(TokenResponse.self, from: data)
    }

    func saveToken(from response: TokenResponse) {
        currentToken = Token(
            accessToken: response.accessToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            scope: response.scope,
            refreshToken: response.refreshToken,
            idToken: response.idToken
        )
        tokenStore.saveToken(
            accessToken: response.accessToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            scope: response.scope,
            refreshToken: response.refreshToken,
            idToken: response.idToken
        )
    }

    func loadToken() -> Token? {
        guard let storedToken = tokenStore.loadToken() else { return nil }
        return storedToken.toAuthManagerToken()
    }
}

private extension StoredToken {
    func toAuthManagerToken() -> AuthManager.Token {
        return AuthManager.Token(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            refreshToken: refreshToken,
            idToken: idToken
        )
    }
}
