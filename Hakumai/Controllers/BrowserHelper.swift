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
    static func extractUrl(fromBrowser browserType: BrowserType) -> String? {
        var source = ""

        switch browserType {
        case .chrome:
            source = "tell application \"Google Chrome\" to get URL of active tab of front window as string"
        case .safari:
            source = "tell application \"Safari\" to get URL of current tab of front window as string"
        default:
            break
        }

        let script = NSAppleScript(source: source)
        var scriptError: NSDictionary?
        let descriptor = script?.executeAndReturnError(&scriptError)

        if scriptError != nil {
            return nil
        }

        var result: String?

        if let unicode = descriptor?.coerce(toDescriptorType: UInt32(typeUnicodeText)) {
            let data = unicode.data
            result = NSString(characters: (data as NSData).bytes.assumingMemoryBound(to: unichar.self), length: (data.count / MemoryLayout<unichar>.size)) as String
        }

        return result
    }
}
