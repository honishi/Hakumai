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
        var red:   CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue:  CGFloat = 0.0
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
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
}

class UIHelper {
    // MARK: - System Message Colors
    static func systemMessageColorBackground() -> NSColor {
        return NSColor.lightGray
    }
    
    // MARK: - Score Colors
    static func scoreColorGreen() -> NSColor {
        return NSColor(rgba: "#24cf20")
    }
    
    static func scoreColorLightGreen() -> NSColor {
        return NSColor(rgba: "#abff00")
    }

    static func scoreColorYellow() -> NSColor {
        return NSColor(rgba: "#ffd900")
    }

    static func scoreColorOrange() -> NSColor {
        return NSColor(rgba: "#ff8c00")
    }

    static func scoreColorRed() -> NSColor {
        return NSColor(rgba: "#ff0000")
    }
    
    // MARK: - Room Colors
    static func roomColorArena() -> NSColor {
        return NSColor(rgba: "#3c49ff")
    }
    
    static func roomColorStandA() -> NSColor {
        return NSColor(rgba: "#ff3c37")
    }
    
    static func roomColorStandB() -> NSColor {
        return NSColor(rgba: "#b2ae00")
    }
    
    static func roomColorStandC() -> NSColor {
        return NSColor(rgba: "#24c10e")
    }
    
    static func roomColorStandD() -> NSColor {
        return NSColor(rgba: "#f577cd")
    }
    
    static func roomColorStandE() -> NSColor {
        return NSColor(rgba: "#2eb9c8")
    }

    static func roomColorStandF() -> NSColor {
        return NSColor(rgba: "#f97900")
    }
    
    static func roomColorStandG() -> NSColor {
        return NSColor(rgba: "#8600d8")
    }
    
    static func roomColorStandH() -> NSColor {
        return NSColor(rgba: "#006b42")
    }
    
    static func roomColorStandI() -> NSColor {
        return NSColor(rgba: "#ac1200")
    }
    
    static func roomColorStandJ() -> NSColor {
        return NSColor(rgba: "#ababab")
    }
    
    // MARK: - Font Attributes
    static func normalCommentAttributes() -> [String: Any] {
        return normalCommentAttributes(fontSize: CGFloat(kDefaultFontSize))
    }
    
    static func normalCommentAttributes(fontSize: CGFloat) -> [String: Any] {
        let attributes = [convertFromNSAttributedStringKey(NSAttributedString.Key.font): NSFont.systemFont(ofSize: fontSize),
                          convertFromNSAttributedStringKey(NSAttributedString.Key.paragraphStyle): NSParagraphStyle.default]
        return attributes
    }

    static func boldCommentAttributes() -> [String: Any] {
        return boldCommentAttributes(fontSize: CGFloat(kDefaultFontSize))
    }

    static func boldCommentAttributes(fontSize: CGFloat) -> [String: Any] {
        let attributes = [convertFromNSAttributedStringKey(NSAttributedString.Key.font): NSFont.boldSystemFont(ofSize: fontSize),
                          convertFromNSAttributedStringKey(NSAttributedString.Key.paragraphStyle): NSParagraphStyle.default]
        return attributes
    }
    
    private static func commonCommentParagraphStyle(fontSize: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.maximumLineHeight = fontSize * 1.2
        return style
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
