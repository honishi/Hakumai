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
        return Array(self)[i]
    }
    
    // "立ち見A列".extractRegexpPattern("立ち見(\\w)列") -> Optional("A")
    // "ab1 cd2 ef3 ab4".extractRegexpPattern("(ab\\d)") -> Optional("ab1")
    // "ab1 cd2 ef3 ab4".extractRegexpPattern("(ab\\d)", index: 0) -> Optional("ab1")
    // "ab1 cd2 ef3 ab4".extractRegexpPattern("(ab\\d)", index: 1) -> Optional("ab4")
    func extractRegexpPattern(pattern: String, index: Int = 0) -> String? {
        let regexp = NSRegularExpression(pattern: pattern, options: nil, error: nil)!
        let matched = regexp.matchesInString(self, options: nil, range: NSMakeRange(0, self.utf16Count))
        // log.debug(matched.count)
        
        if matched.count < index + 1 {
            return nil
        }
        
        let nsRange = matched[index].rangeAtIndex(1)
        let start = advance(self.startIndex, nsRange.location)
        let end = advance(self.startIndex, nsRange.location + nsRange.length)
        let range = Range<String.Index>(start: start, end: end)
        let substring = self.substringWithRange(range)
        
        return substring
    }
    
    func hasRegexpPattern(pattern: String) -> Bool {
        return (self.extractRegexpPattern("(" + pattern + ")") != nil)
    }
    
    func stringByRemovingPattern(pattern: String) -> String {
        let regexp = NSRegularExpression(pattern: pattern, options: nil, error: nil)!
        let removed = regexp.stringByReplacingMatchesInString(self, options: nil, range: NSMakeRange(0, self.utf16Count), withTemplate: "")
        
        return removed
    }
    
    func numberStringWithSeparatorComma() -> String? {
        let intValue: Int! = self.toInt()
        
        if intValue == nil {
            return nil
        }
        
        var number = NSNumber(integer: intValue)
        
        var formatter = NSNumberFormatter()
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
