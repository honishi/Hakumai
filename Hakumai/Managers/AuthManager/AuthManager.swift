//
//  AuthManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/21.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

private let authWebBaseUrl = "https://oauth.nicovideo.jp"
private let authWebPath = "/oauth2/authorize?response_type=code&client_id=\(hakumaiClientId)"

protocol AuthManagerProtocol {
    var authWebUrl: URL { get }
    var hasToken: Bool { get }
    var currentToken: AuthManagerToken? { get }

    func extractCallbackResponseAndSaveToken(response: String, completion: (Result<AuthManagerToken, AuthManagerError>) -> Void)
    func refreshToken(completion: @escaping (Result<AuthManagerToken, AuthManagerError>) -> Void)
    func clearToken()

    // debug function
    func injectExpiredAccessToken()
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
    case noRefreshToken
    case refreshTokenFailed
    case `internal`
}

extension AuthManager {
    static let shared = AuthManager(tokenStore: TokenStore())
}

final class AuthManager: AuthManagerProtocol {
    // MARK: Properties
    lazy var authWebUrl: URL = makeAuthWebUrl(useDevServer: useDevServer)
    var hasToken: Bool { currentToken != nil }

    private let session: Session
    private let tokenStore: TokenStoreProtocol
    private(set) var currentToken: AuthManagerToken?
    private lazy var refreshTokenApiUrl: URL = makeRefreshTokenApiUrl(useDevServer: useDevServer)
    private var refreshTokenCompletions: [(Result<AuthManagerToken, AuthManagerError>) -> Void] = []

    init(tokenStore: TokenStoreProtocol) {
        session = {
            let configuration = URLSessionConfiguration.af.default
            // XXX: Configure the `configuration` if needed.
            return Session(configuration: configuration)
        }()
        self.tokenStore = tokenStore
        currentToken = loadToken()
        log.debug("")
    }
}

extension AuthManager {
    func extractCallbackResponseAndSaveToken(response: String, completion: (Result<AuthManagerToken, AuthManagerError>) -> Void) {
        guard let response = decodeTokenResponse(from: response) else {
            completion(.failure(.internal))
            return
        }
        log.debug(response)
        let token = response.toAuthManagerToken()
        saveToken(from: token)
        completion(.success(token))
    }

    func refreshToken(completion: @escaping (Result<AuthManagerToken, AuthManagerError>) -> Void) {
        // XXX: Check if the following implementation is valid for multi-thread.
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let refreshToken = currentToken?.refreshToken else {
            completion(.failure(.noRefreshToken))
            return
        }

        // If the refresh token request has already invoked by another thread,
        // just store the completion and skip the request.
        let isRefreshing = !refreshTokenCompletions.isEmpty
        refreshTokenCompletions.append(completion)
        log.debug(refreshTokenCompletions)
        if isRefreshing {
            log.debug("Skipped the refresh token request since it has already requested.")
            return
        }

        var request = URLRequest(url: refreshTokenApiUrl)
        request.method = .post
        request.httpBody = "refresh_token=\(refreshToken)".data(using: .utf8)
        session.request(request)
            .cURLDescription { log.debug($0) }
            .validate()
            .responseString { [weak self] in
                defer {
                    self?.refreshTokenCompletions.removeAll()
                    log.debug(self?.refreshTokenCompletions)
                }
                guard let me = self else { return }
                // log.debug($0)
                switch $0.result {
                case .success(let string):
                    log.debug("Refresh token successfully completed.")
                    log.debug(string)
                    guard let response = me.decodeTokenResponse(from: string) else {
                        self?.refreshTokenCompletions.forEach { $0(.failure(.internal)) }
                        return
                    }
                    let token = response.toAuthManagerToken()
                    me.saveToken(from: token)
                    self?.refreshTokenCompletions.forEach { $0(.success(token)) }
                case .failure(let error):
                    log.error(error)
                    if error.isNetworkError {
                        // Do nothing for this case. This might be temporary situation.
                        log.debug("Failed to refresh token, but skip to clear token since it's by network error.")
                    } else {
                        // Clearing possible "useless" stored token.
                        log.debug("Failed to refresh token, so clearing the token since it's possibly unusable one.")
                        me.clearToken()
                    }
                    self?.refreshTokenCompletions.forEach { $0(.failure(.refreshTokenFailed)) }
                }
            }
    }

    func clearToken() {
        currentToken = nil
        tokenStore.clearToken()
    }
}

extension AuthManager {
    func injectExpiredAccessToken() {
        guard let token = currentToken else { return }
        currentToken = AuthManagerToken(
            accessToken: debugExpiredAccessToken,
            tokenType: token.tokenType,
            expiresIn: token.expiresIn,
            scope: token.scope,
            refreshToken: token.refreshToken,
            idToken: token.idToken
        )
        tokenStore.saveToken(token.toStoredToken())
    }
}

private extension AuthManager {
    func makeAuthWebUrl(useDevServer: Bool = false) -> URL {
        // swiftlint:disable force_unwrapping
        let devCallback = devAuthCallbackUrl.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let url = authWebBaseUrl
            + authWebPath
            + (useDevServer ? "&redirect_uri=\(devCallback)" : "")
        return URL(string: url)!
        // swiftlint:enable force_unwrapping
    }

    func makeRefreshTokenApiUrl(useDevServer: Bool = false) -> URL {
        // swiftlint:disable force_unwrapping
        let url = (useDevServer ? devHakumaiServerApiBaseUrl : hakumaiServerApiBaseUrl)
            + hakumaiServerApiPathRefreshToken
        return URL(string: url)!
        // swiftlint:enable force_unwrapping
    }

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
        AuthManagerToken(
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
        StoredToken(
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
        AuthManagerToken(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            refreshToken: refreshToken,
            idToken: idToken
        )
    }
}
