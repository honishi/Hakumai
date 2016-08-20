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
    class func requestLoginCookie(mailAddress: String, password: String, completion: @escaping (_ userSessionCookie: String?) -> Void) {
        LoginCookie.requestCookie(mailAddress: mailAddress, password: password, completion: completion)
    }
    
    class func requestBrowserCookieWithBrowserType(_ browserType: BrowserType) -> String? {
        switch (browserType) {
        case .chrome:
            return ChromeCookie.storedCookie()
        default:
            break
        }
        
        return nil
    }
}
