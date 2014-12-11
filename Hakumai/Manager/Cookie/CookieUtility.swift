//
//  CookieUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class CookieUtility {
    enum BrowserType {
        case Chrome
        case Safari
        case Firefox
    }
    
    // MARK: - Public Functions
    class func cookie(browserType: BrowserType) -> String? {
        switch (browserType) {
        case .Chrome:
            return ChromeCookie.cookie()
        case .Safari, .Firefox:
            // TODO: not implemented yet
            return nil
        }
    }
}