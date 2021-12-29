//
//  NSColor+Extensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/28.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Cocoa

extension NSColor {
    // based on https://github.com/yeahdongcn/UIColor-Hex-Swift
    convenience init(hex: String) {
        guard hex.hasPrefix("#") else {
            fatalError("invalid rgb string, missing '#' as prefix")
        }

        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0

        let index = hex.index(hex.startIndex, offsetBy: 1)
        let _hex = String(hex[index...])
        let scanner = Scanner(string: _hex)
        var hexValue: CUnsignedLongLong = 0

        guard scanner.scanHexInt64(&hexValue) else {
            fatalError("scan hex error")
        }

        if _hex.count == 6 {
            red   = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((hexValue & 0x00FF00) >> 8)  / 255.0
            blue  = CGFloat(hexValue & 0x0000FF) / 255.0
        } else if _hex.count == 8 {
            red   = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            green = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            blue  = CGFloat((hexValue & 0x0000FF00) >> 8)  / 255.0
            alpha = CGFloat(hexValue & 0x000000FF)         / 255.0
        } else {
            fatalError("invalid rgb string, length should be 7 or 9")
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    // https://stackoverflow.com/a/39431678/13220031
    var hex: String {
        guard let rgbColor = usingColorSpaceName(NSColorSpaceName.calibratedRGB) else {
            return "#FFFFFF"
        }
        let red = Int(round(rgbColor.redComponent * 0xFF))
        let green = Int(round(rgbColor.greenComponent * 0xFF))
        let blue = Int(round(rgbColor.blueComponent * 0xFF))
        let hexString = NSString(format: "#%02X%02X%02X", red, green, blue)
        return hexString as String
    }
}
