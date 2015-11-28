//
//  CommonExtensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/17/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: - String

// enabling intuitive operation to get nth Character from String
// based on http://stackoverflow.com/a/24144365
extension String {
    subscript (i: Int) -> Character {
        return Array(characters)[i]
    }
    
    // "立ち見A列".extractRegexpPattern("立ち見(\\w)列") -> Optional("A")
    func extractRegexpPattern(pattern: String) -> String? {
        // convert String to NSString to handle regular expression as expected.
        // with String, we could not handle the pattern like "ﾊﾃﾞだなｗ".extranctRegexpPattern("(ｗ)")
        // see details at http://stackoverflow.com/a/27192734
        let nsStringSelf = (self as NSString)
        
        let regexp: NSRegularExpression! = try? NSRegularExpression(pattern: pattern, options: [])
        if regexp == nil {
            return nil
        }
        
        let matched = regexp.firstMatchInString(nsStringSelf as String, options: [], range: NSMakeRange(0, nsStringSelf.length))
        if matched == nil {
            return nil
        }
        
        let nsRange = matched!.rangeAtIndex(1)
        let nsSubstring = nsStringSelf.substringWithRange(nsRange)

        return (nsSubstring as String)
    }
    
    func hasRegexpPattern(pattern: String) -> Bool {
        return (extractRegexpPattern("(" + pattern + ")") != nil)
    }
    
    func stringByRemovingPattern(pattern: String) -> String {
        let nsStringSelf = (self as NSString)
        
        let regexp = try! NSRegularExpression(pattern: pattern, options: [])
        let removed = regexp.stringByReplacingMatchesInString(nsStringSelf as String, options: [], range: NSMakeRange(0, nsStringSelf.length), withTemplate: "")
        
        return (removed as String)
    }
    
    func numberStringWithSeparatorComma() -> String? {
        let intValue: Int! = Int(self)
        
        if intValue == nil {
            return nil
        }
        
        let number = NSNumber(integer: intValue)
        
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .DecimalStyle
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        
        return formatter.stringFromNumber(number)
    }
}

func * (left: String, right: Int) -> String {
    if right == 0 {
        return ""
    }
    
    var multiplied = ""
    
    for _ in 1...right {
        multiplied += left
    }
    
    return multiplied
}
