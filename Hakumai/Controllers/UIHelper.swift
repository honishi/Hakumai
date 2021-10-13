//
//  UIHelper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// based on https://github.com/yeahdongcn/UIColor-Hex-Swift
extension NSColor {
    convenience init(rgba: String) {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0

        if rgba.hasPrefix("#") {
            let index   = rgba.index(rgba.startIndex, offsetBy: 1)
            let hex     = String(rgba[index...])
            let scanner = Scanner(string: hex)
            var hexValue: CUnsignedLongLong = 0
            if scanner.scanHexInt64(&hexValue) {
                if hex.count == 6 {
                    red   = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
                    green = CGFloat((hexValue & 0x00FF00) >> 8)  / 255.0
                    blue  = CGFloat(hexValue & 0x0000FF) / 255.0
                } else if hex.count == 8 {
                    red   = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
                    green = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
                    blue  = CGFloat((hexValue & 0x0000FF00) >> 8)  / 255.0
                    alpha = CGFloat(hexValue & 0x000000FF)         / 255.0
                } else {
                    print("invalid rgb string, length should be 7 or 9", terminator: "")
                }
            } else {
                print("scan hex error")
            }
        } else {
            print("invalid rgb string, missing '#' as prefix", terminator: "")
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

final class UIHelper {
    // MARK: - System Message Colors
    static func systemMessageColorBackground() -> NSColor {
        return NSColor.lightGray
    }

    // MARK: - Score Colors
    static func scoreColorGreen() -> NSColor {
        return NSColor(rgba: "#0EA50B")
    }

    // MARK: - Room Colors
    static func roomColorArena() -> NSColor {
        return NSColor(rgba: "#3c49ff")
    }

    // MARK: - Font Attributes
    static func normalCommentAttributes() -> [String: Any] {
        return normalCommentAttributes(fontSize: CGFloat(kDefaultFontSize))
    }

    static func normalCommentAttributes(fontSize: CGFloat) -> [String: Any] {
        let attributes = [NSAttributedString.Key.font.rawValue: NSFont.systemFont(ofSize: fontSize),
                          NSAttributedString.Key.paragraphStyle.rawValue: NSParagraphStyle.default]
        return attributes
    }

    static func boldCommentAttributes() -> [String: Any] {
        return boldCommentAttributes(fontSize: CGFloat(kDefaultFontSize))
    }

    static func boldCommentAttributes(fontSize: CGFloat) -> [String: Any] {
        let attributes = [NSAttributedString.Key.font.rawValue: NSFont.boldSystemFont(ofSize: fontSize),
                          NSAttributedString.Key.paragraphStyle.rawValue: NSParagraphStyle.default]
        return attributes
    }

    private static func commonCommentParagraphStyle(fontSize: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.maximumLineHeight = fontSize * 1.2
        return style
    }
}
