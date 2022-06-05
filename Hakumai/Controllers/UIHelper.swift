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

    static func roomColor(roomPosition: RoomPosition) -> NSColor {
        switch roomPosition {
        case .arena:
            return NSColor(hex: "#3C49FF")
        case .storeA, .storeB, .storeC, .storeD, .storeE, .storeF, .storeG, .storeH, .storeI, .storeJ:
            return NSColor(hex: "#CB4C15")
        }
    }

    static func cellViewAdFlashColor() -> NSColor {
        return colorIf(light: "#FFBD2F", dark: "#E09900")
    }

    static func cellViewGiftFlashColor() -> NSColor {
        return colorIf(light: "#E5444F", dark: "#D01C24")
    }

    static func casterCommentColor() -> NSColor {
        return colorIf(light: "#D22E1B", dark: "#FF8170")
    }

    // MARK: - Font Attributes
    static func commentAttributes(
        fontSize: CGFloat = CGFloat(kDefaultFontSize),
        isBold: Bool = false,
        isRed: Bool = false
    ) -> [NSAttributedString.Key: Any] {
        return [
            .font: isBold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: isRed ? casterCommentColor() : NSColor.labelColor,
            .paragraphStyle: NSParagraphStyle.default
        ]
    }
}

private extension UIHelper {
    static func colorIf(light: String, dark: String) -> NSColor {
        if #available(macOS 10.14, *) {
            return NSApplication.shared.isDarkMode ? NSColor(hex: dark) : NSColor(hex: light)
        } else {
            return NSColor(hex: light)
        }
    }
}

private extension NSApplication {
    var isDarkMode: Bool {
        if #available(OSX 10.14, *) {
            return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return false
    }
}
