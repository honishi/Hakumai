//
//  LoginCookie.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/6/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kNicoVideoDomain = "http://nicovideo.jp"
private let kLoginUrl = "https://secure.nicovideo.jp/secure/login?site=niconico"

// request header
private let kUserAgent = kCommonUserAgent

final class LoginCookie {
    // MARK: - Public Functions
    static func requestCookie(mailAddress: String, password: String, completion: @escaping (_ userSessionCookie: String?) -> Void) {
        func httpCompletion(_ response: URLResponse?, _ data: Data?, _ connectionError: Error?) {
            if let connectionError = connectionError {
                log.error("login failed. connection error:[\(connectionError)]")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode != 200 {
                log.error("login failed. got unexpected status code::[\(httpResponse.statusCode)]")
                completion(nil)
                return
            }

            guard let userSessionCookie = LoginCookie.findUserSessionCookie() else {
                completion(nil)
                return
            }
            log.debug("found session cookie:[\(userSessionCookie)]")

            completion(userSessionCookie)
        }

        LoginCookie.removeAllStoredCookie()

        let parameters = "mail=\(mailAddress)&password=\(password)"

        guard let url = URL(string: kLoginUrl) else { return }
        let request = NSMutableURLRequest(url: url)
        request.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        request.httpMethod = "POST"
        request.httpBody = parameters.data(using: String.Encoding.utf8)

        let queue = OperationQueue()
        NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: queue, completionHandler: httpCompletion)
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
