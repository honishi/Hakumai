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
        let dark = "#C98508"
        if #available(macOS 10.14, *) {
            return NSApplication.shared.isDarkMode ? NSColor(hex: dark) : NSColor(hex: light)
        } else {
            return NSColor(hex: light)
        }
    }

    static func cellViewGiftFlashColor() -> NSColor {
        let light = "#D01C24"
        let dark = light
        if #available(macOS 10.14, *) {
            return NSApplication.shared.isDarkMode ? NSColor(hex: dark) : NSColor(hex: light)
        } else {
            return NSColor(hex: light)
        }
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

extension NSApplication {
    var isDarkMode: Bool {
        if #available(OSX 10.14, *) {
            return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return false
    }
}
