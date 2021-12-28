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
    static func systemMessageColorBackground() -> NSColor {
        return NSColor(hex: "#808080")
    }

    static func debugMessageColorBackground() -> NSColor {
        return NSColor(hex: "#101010")
    }

    static func scoreColorGreen() -> NSColor {
        return NSColor(hex: "#0EA50B")
    }

    static func roomColorArena() -> NSColor {
        return NSColor(hex: "#3c49ff")
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
