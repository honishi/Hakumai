//
//  NicoUtilityHttpClient.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// request header
private let kUserAgent = kCommonUserAgent
private let kCookieDomain = "nicovideo.jp"
private let kCookieExpire = TimeInterval(7200)
private let kCookiePath = "/"

// Internal Http Utility
extension _NicoUtility {
    func cookiedAsyncRequest(httpMethod: String, url: String, parameters: [String: Any]?, completion: @escaping (URLResponse?, Data?, Error?) -> Void) {}

    func construct(parameters: [String: Any]?) -> String? {
        guard let parameters = parameters else { return nil }

        var constructed: String = ""

        for (key, value) in parameters {
            if 0 < constructed.count {
                constructed = constructed as String + "&"
            }
            constructed = constructed as String + "\(key)=\(value)"
        }

        // use custom escape character sets instead of NSCharacterSet.URLQueryAllowedCharacterSet()
        // cause we need to escape strings like this: tpos=1416842780%2E802121&comment%5Flocale=ja%2Djp
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: "?=&")

        return constructed.addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)
    }

    private func mutableRequest(customHeaders url: String) -> NSMutableURLRequest {
        guard let urlObject = URL(string: url) else { return NSMutableURLRequest() }
        let mutableRequest = NSMutableURLRequest(url: urlObject)
        mutableRequest.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        return mutableRequest
    }

    private func sessionCookies() -> [HTTPCookie]? {
        // log.debug("userSessionCookie:[\(userSessionCookie)]")
        guard let userSessionCookie = userSessionCookie else { return nil }

        var cookies = [HTTPCookie]()

        for (name, value) in [("user_session", userSessionCookie), ("area", "JP"), ("lang", "ja-jp")] {
            if let cookie = HTTPCookie(properties: [
                                        HTTPCookiePropertyKey.domain: kCookieDomain,
                                        HTTPCookiePropertyKey.name: name,
                                        HTTPCookiePropertyKey.value: value,
                                        HTTPCookiePropertyKey.expires: Date().addingTimeInterval(kCookieExpire),
                                        HTTPCookiePropertyKey.path: kCookiePath]) {
                cookies.append(cookie)
            }
        }

        return cookies
    }
}

private let kPostCommentUrl = "https://api.cas.nicovideo.jp/v1/services/live/programs/%@/comments"

extension _NicoUtility {
    func postCommentRequest(lv: String, json: [String: Any], completion: @escaping (URLResponse?, Data?, Error?) -> Void) {}
}
