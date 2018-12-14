//
//  CookieUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class CookieUtility {
    // MARK: - Public Functions
    static func requestLoginCookie(mailAddress: String, password: String, completion: @escaping (_ userSessionCookie: String?) -> Void) {
        LoginCookie.requestCookie(mailAddress: mailAddress, password: password, completion: completion)
    }

    static func requestBrowserCookie(browserType: BrowserType, completion: @escaping(String?) -> Void) {
        switch browserType {
        case .chrome:
            completion(ChromeCookie.storedCookie())
        case .safari:
            SafariCookie.storedCookie(callback: { cookie in
                completion(cookie)
            })
        default:
            break
        }
    }
}
