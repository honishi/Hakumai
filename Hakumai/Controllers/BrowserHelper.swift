//
//  BrowserHelper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/20/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class BrowserHelper {
    enum BrowserType {
        case chrome
        case safari
        case firefox
    }
    
    // http://stackoverflow.com/a/6111592
    class func urlFromBrowser(_ browserType: BrowserType) -> String? {
        var browserName = ""
        
        switch browserType {
        case .chrome:
            browserName = "Google Chrome"
        case .safari:
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
        
        if let unicode = descriptor?.coerce(toDescriptorType: UInt32(typeUnicodeText)) {
            let data = unicode.data
            result = NSString(characters: UnsafePointer<unichar>((data as NSData).bytes), length: (data.count / sizeof(unichar))) as String
        }
        
        return result
    }
}
