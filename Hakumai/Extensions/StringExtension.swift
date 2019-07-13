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
        return self[index(startIndex, offsetBy: i)]
    }

    // "立ち見A列".extractRegexp(pattern: "立ち見(\\w)列") -> Optional("A")
    func extractRegexp(pattern: String) -> String? {
        // convert String to NSString to handle regular expression as expected.
        // with String, we could not handle the pattern like "ﾊﾃﾞだなｗ".extranctRegexpPattern("(ｗ)")
        // see details at http://stackoverflow.com/a/27192734
        let nsStringSelf = (self as NSString)

        guard let regexp = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        let matched = regexp.firstMatch(in: nsStringSelf as String, options: [], range: NSRange(location: 0, length: nsStringSelf.length))
        if matched == nil {
            return nil
        }

        guard let nsRange = matched?.range(at: 1) else { return nil }
        let nsSubstring = nsStringSelf.substring(with: nsRange)

        return (nsSubstring as String)
    }

    func hasRegexp(pattern: String) -> Bool {
        return (extractRegexp(pattern: "(" + pattern + ")") != nil)
    }

    func stringByRemovingRegexp(pattern: String) -> String {
        let nsStringSelf = (self as NSString)
        guard let regexp = try? NSRegularExpression(pattern: pattern, options: []) else { return self }
        let removed = regexp.stringByReplacingMatches(
            in: nsStringSelf as String,
            options: [],
            range: NSRange(location: 0, length: nsStringSelf.length),
            withTemplate: "")
        return (removed as String)
    }

    func numberStringWithSeparatorComma() -> String {
        guard let intValue = Int(self) else { return "" }

        let number = NSNumber(value: intValue)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3

        return formatter.string(from: number) ?? ""
    }
}

extension String {
    func extractLiveNumber() -> Int? {
        let liveNumberPattern = "\\d{9,}"
        let patterns = [
            "http:\\/\\/live\\.nicovideo\\.jp\\/watch\\/lv(" + liveNumberPattern + ").*",
            "lv(" + liveNumberPattern + ")",
            "(" + liveNumberPattern + ")"
        ]
        for pattern in patterns {
            if let extracted = extractRegexp(pattern: pattern), let number = Int(extracted) {
                return number
            }
        }
        return nil
    }

    func extractUrlString() -> String? {
        return extractRegexp(pattern: "(https?://[\\w/:%#\\$&\\?\\(\\)~\\.=\\+\\-]+)")
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
