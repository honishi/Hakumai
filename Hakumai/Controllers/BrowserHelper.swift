//
//  BrowserHelper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/20/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// logger for class methods
private let log = XCGLogger.defaultInstance()

class BrowserHelper {
    enum BrowserType {
        case Chrome
        case Safari
        case Firefox
    }
    
    // http://stackoverflow.com/a/6111592
    class func urlFromBrowser(browserType: BrowserType) -> String? {
        var browserName = ""
        
        switch browserType {
        case .Chrome:
            browserName = "Google Chrome"
        case .Safari:
            browserName = "Safari"
        default:
            break
        }
        
        let script = NSAppleScript(source: "tell application \"\(browserName)\" to get URL of active tab of front window as string")
        var scriptError: NSDictionary?
        let descriptor = script?.executeAndReturnError(&scriptError)
        
        if scriptError != nil {
            return nil
        }
        
        var result: String?
        
        if let unicode = descriptor?.coerceToDescriptorType(UInt32(typeUnicodeText)) {
            let data = unicode.data
            result = NSString(characters: UnsafePointer<unichar>(data.bytes), length: (data.length / sizeof(unichar))) as String
        }
        
        return result
    }
}
