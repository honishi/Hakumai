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
    var hasToken: Bool { get }
    var currentToken: AuthManagerToken? { get }

    func extractCallbackResponseAndSaveToken(response: String, completion: ((Result<AuthManagerToken, AuthManagerError>) -> Void))
    func refreshToken(completion: @escaping ((Result<AuthManagerToken, AuthManagerError>) -> Void))
    func clearToken()
}

struct AuthManagerToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let refreshToken: String
    let idToken: String?
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
    // MARK: Properties
    var hasToken: Bool { currentToken != nil }
    private let tokenStore: TokenStoreProtocol
    private(set) var currentToken: AuthManagerToken?

    init(tokenStore: TokenStoreProtocol) {
        self.tokenStore = tokenStore
        currentToken = loadToken()
        log.debug("")
    }
}

extension AuthManager {
    func extractCallbackResponseAndSaveToken(response: String, completion: ((Result<AuthManagerToken, AuthManagerError>) -> Void)) {
        guard let response = decodeTokenResponse(from: response) else {
            completion(.failure(.decode))
            return
        }
        log.debug(response)
        let token = response.toAuthManagerToken()
        saveToken(from: token)
        completion(.success(token))
    }

    func refreshToken(completion: @escaping ((Result<AuthManagerToken, AuthManagerError>) -> Void)) {
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
                    guard let response = me.decodeTokenResponse(from: string) else {
                        completion(.failure(.decode))
                        return
                    }
                    let token = response.toAuthManagerToken()
                    me.saveToken(from: token)
                    completion(.success(token))
                case .failure(let error):
                    log.error(error)
                    completion(.failure(.refreshTokenFailed))
                }
            }
    }

    func clearToken() {
        currentToken = nil
        tokenStore.clearToken()
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

    func saveToken(from token: AuthManagerToken) {
        currentToken = token
        tokenStore.saveToken(token.toStoredToken())
    }

    func loadToken() -> AuthManagerToken? {
        guard let storedToken = tokenStore.loadToken() else { return nil }
        return storedToken.toAuthManagerToken()
    }
}

private extension TokenResponse {
    func toAuthManagerToken() -> AuthManagerToken {
        return AuthManagerToken(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            refreshToken: refreshToken,
            idToken: idToken
        )
    }
}

private extension AuthManagerToken {
    func toStoredToken() -> StoredToken {
        return StoredToken(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            refreshToken: refreshToken,
            idToken: idToken
        )
    }
}

private extension StoredToken {
    func toAuthManagerToken() -> AuthManagerToken {
        return AuthManagerToken(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            refreshToken: refreshToken,
            idToken: idToken
        )
    }
}
