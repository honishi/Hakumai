//
//  BrowserHelper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/20/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let appNameChrome = "Google Chrome"
private let appNameSafari = "Safari"

private let chromeScript = """
if application "\(appNameChrome)" is running then
  tell application "\(appNameChrome)" to get URL of active tab of front window as string
end if
"""

private let safariScript = """
if application "\(appNameSafari)" is running then
  tell application "\(appNameSafari)" to get URL of current tab of front window as string
end if
"""

final class BrowserHelper {
    enum BrowserType {
        case chrome
        case safari
        case firefox
    }

    // http://stackoverflow.com/a/6111592
    static func extractUrl(fromBrowser browserType: BrowserType) -> String? {
        let source = { () -> String in
            switch browserType {
            case .chrome:   return chromeScript
            case .safari:   return safariScript
            default:        return ""
            }
        }()
        let script = NSAppleScript(source: source)
        var scriptError: NSDictionary?
        let descriptor = script?.executeAndReturnError(&scriptError)

        guard scriptError == nil else {
            log.error(scriptError)
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

extension BrowserInUseType {
    var toBrowserHelperBrowserType: BrowserHelper.BrowserType {
        return {
            switch self {
            case .chrome:   return .chrome
            case .safari:   return .safari
            }
        }()
    }
}
