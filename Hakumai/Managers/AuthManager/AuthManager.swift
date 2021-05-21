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
            .responseData {
                log.debug($0)
                switch $0.result {
                case .success(let data):
                    // TODO: extract
                    log.debug(data)
                    completion(.success(()))
                case .failure(_):
                    completion(.failure(.refreshTokenFailed))
                }
            }
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
