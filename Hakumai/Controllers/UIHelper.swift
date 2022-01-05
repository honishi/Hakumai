//
//  UIHelper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class UIHelper {
    // MARK: - Main Window Colors
    static func systemMessageBgColor() -> NSColor {
        return NSColor(hex: "#808080")
    }

    static func debugMessageBgColor() -> NSColor {
        return NSColor(hex: "#101010")
    }

    static func greenScoreColor() -> NSColor {
        return NSColor(hex: "#0EA50B")
    }

    static func arenaRoomColor() -> NSColor {
        return NSColor(hex: "#3C49FF")
    }

    static func cellViewAdFlashColor() -> NSColor {
        let light = "#FFBD2F"
        let dark = "#E09900"
        if #available(macOS 10.14, *) {
            return NSApplication.shared.isDarkMode ? NSColor(hex: dark) : NSColor(hex: light)
        } else {
            return NSColor(hex: light)
        }
    }

    static func cellViewGiftFlashColor() -> NSColor {
        let light = "#E5444F"
        let dark = "#D01C24"
        if #available(macOS 10.14, *) {
            return NSApplication.shared.isDarkMode ? NSColor(hex: dark) : NSColor(hex: light)
        } else {
            return NSColor(hex: light)
        }
    }

    // MARK: - Font Attributes
    static func commentAttributes(
        fontSize: CGFloat = CGFloat(kDefaultFontSize),
        isBold: Bool = false,
        isRed: Bool = false
    ) -> [NSAttributedString.Key: Any] {
        return [
            NSAttributedString.Key.font:
                isBold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize),
            NSAttributedString.Key.paragraphStyle: NSParagraphStyle.default,
            NSAttributedString.Key.foregroundColor: isRed ? NSColor.red : NSColor.labelColor
        ]
    }
}

extension NSApplication {
    var isDarkMode: Bool {
        if #available(OSX 10.14, *) {
            return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return false
    }
}
