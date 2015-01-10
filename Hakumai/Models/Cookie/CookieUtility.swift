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
    class func requestLoginCookieWithMailAddress(mailAddress: String, password: String, completion: (userSessionCookie: String?) -> Void) {
        LoginCookie.requestCookieWithMailAddress(mailAddress, password: password, completion: completion)
    }
    
    class func requestBrowserCookieWithBrowserType(browserType: BrowserType) -> String? {
        switch (browserType) {
        case .Chrome:
            return ChromeCookie.storedCookie()
        default:
            break
        }
        
        return nil
    }
}