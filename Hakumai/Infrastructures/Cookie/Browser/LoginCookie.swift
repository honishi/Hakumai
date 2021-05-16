//
//  LoginCookie.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/6/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

private let kNicoVideoDomain = "http://nicovideo.jp"
private let kLoginUrl = "https://secure.nicovideo.jp/secure/login?site=niconico"

final class LoginCookie {
    // MARK: - Public Functions
    static func requestCookie(mailAddress: String, password: String, completion: @escaping (_ userSessionCookie: String?) -> Void) {
        LoginCookie.removeAllStoredCookie()

        guard let url = URL(string: kLoginUrl) else {
            fatalError("This is NOT going to be happened.")
        }

        var request = URLRequest(url: url)
        request.method = .post
        request.allHTTPHeaderFields = [commonUserAgentKey: commonUserAgentValue]
        request.httpBody = "mail=\(mailAddress)&password=\(password)".data(using: .utf8)

        AF.request(request).response {
            switch $0.result {
            case .success:
                guard let userSessionCookie = LoginCookie.findUserSessionCookie() else {
                    completion(nil)
                    return
                }
                log.debug("found session cookie:[\(userSessionCookie)]")
                completion(userSessionCookie)

            case .failure(let error):
                log.error("login failed. got unexpected error:[\(error)]")
                completion(nil)
            }
        }
    }
}

// MARK: - Internal Functions
private extension LoginCookie {
    static func removeAllStoredCookie() {
        let cookieStorage = HTTPCookieStorage.shared
        guard let url = URL(string: kNicoVideoDomain),
              let cookies = cookieStorage.cookies(for: url) else { return }
        for cookie in cookies {
            cookieStorage.deleteCookie((cookie ))
        }
    }

    static func findUserSessionCookie() -> String? {
        let cookieStorage = HTTPCookieStorage.shared
        guard let url = URL(string: kNicoVideoDomain),
              let cookies = cookieStorage.cookies(for: url) else { return nil }
        for cookie in cookies where cookie.name == "user_session" {
            return cookie.value
        }
        return nil
    }
}
