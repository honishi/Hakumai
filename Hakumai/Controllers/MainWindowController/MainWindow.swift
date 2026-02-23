//
//  MainWindow.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/09.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class MainWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        // Keep scope minimal: support only Command / Shift+Command variants.
        let unsupportedModifiers: NSEvent.ModifierFlags = [.option, .control, .function]
        guard modifiers.intersection(unsupportedModifiers).isEmpty else {
            return super.performKeyEquivalent(with: event)
        }

        guard let mainWindowController = windowController as? MainWindowController,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "f":
            guard !modifiers.contains(.shift) else {
                return super.performKeyEquivalent(with: event)
            }
            mainWindowController.showCommentSearch()
            return true
        case "g":
            if modifiers.contains(.shift) {
                mainWindowController.findPreviousComment()
            } else {
                mainWindowController.findNextComment()
            }
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
