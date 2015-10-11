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
            let index   = rgba.startIndex.advancedBy(1)
            let hex     = rgba.substringFromIndex(index)
            let scanner = NSScanner(string: hex)
            var hexValue: CUnsignedLongLong = 0
            if scanner.scanHexLongLong(&hexValue) {
                if hex.characters.count == 6 {
                    red   = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
                    green = CGFloat((hexValue & 0x00FF00) >> 8)  / 255.0
                    blue  = CGFloat(hexValue & 0x0000FF) / 255.0
                } else if hex.characters.count == 8 {
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
    class func systemMessageColorBackground() -> NSColor {
        return NSColor.lightGrayColor()
    }
    
    // MARK: - Score Colors
    class func scoreColorGreen() -> NSColor {
        return NSColor(rgba: "#24cf20")
    }
    
    class func scoreColorLightGreen() -> NSColor {
        return NSColor(rgba: "#abff00")
    }

    class func scoreColorYellow() -> NSColor {
        return NSColor(rgba: "#ffd900")
    }

    class func scoreColorOrange() -> NSColor {
        return NSColor(rgba: "#ff8c00")
    }

    class func scoreColorRed() -> NSColor {
        return NSColor(rgba: "#ff0000")
    }
    
    // MARK: - Room Colors
    class func roomColorArena() -> NSColor {
        return NSColor(rgba: "#3c49ff")
    }
    
    class func roomColorStandA() -> NSColor {
        return NSColor(rgba: "#ff3c37")
    }
    
    class func roomColorStandB() -> NSColor {
        return NSColor(rgba: "#b2ae00")
    }
    
    class func roomColorStandC() -> NSColor {
        return NSColor(rgba: "#24c10e")
    }
    
    class func roomColorStandD() -> NSColor {
        return NSColor(rgba: "#f577cd")
    }
    
    class func roomColorStandE() -> NSColor {
        return NSColor(rgba: "#2eb9c8")
    }

    class func roomColorStandF() -> NSColor {
        return NSColor(rgba: "#f97900")
    }
    
    class func roomColorStandG() -> NSColor {
        return NSColor(rgba: "#8600d8")
    }
    
    class func roomColorStandH() -> NSColor {
        return NSColor(rgba: "#006b42")
    }
    
    class func roomColorStandI() -> NSColor {
        return NSColor(rgba: "#ac1200")
    }
    
    class func roomColorStandJ() -> NSColor {
        return NSColor(rgba: "#ababab")
    }
    
    // MARK: - Font Attributes
    class func normalCommentAttributes() -> [NSString: AnyObject] {
        let attributes = [NSFontAttributeName: NSFont.systemFontOfSize(13),
            NSParagraphStyleAttributeName: NSParagraphStyle.defaultParagraphStyle()]
        return attributes
    }
    
    class func boldCommentAttributes() -> [NSString: AnyObject] {
        let attributes = [NSFontAttributeName: NSFont.boldSystemFontOfSize(13),
            NSParagraphStyleAttributeName: NSParagraphStyle.defaultParagraphStyle()]
        return attributes
    }
}
