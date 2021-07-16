//
//  NSWindowExtension.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/15/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let windowLevelKeyForNormal: CGWindowLevelKey = .normalWindow
private let windowLevelKeyForAlwaysOnTop: CGWindowLevelKey = .floatingWindow

extension NSWindow {
    // http://qiita.com/rryu/items/04af65d772e81d2beb7a
    var alwaysOnTop: Bool {
        get {
            let windowLevel = Int(CGWindowLevelForKey(windowLevelKeyForAlwaysOnTop))
            return level.rawValue == windowLevel
        }

        set(newAlwaysOnTop) {
            let windowLevelKey = newAlwaysOnTop ? windowLevelKeyForAlwaysOnTop : windowLevelKeyForNormal
            let windowLevel = Int(CGWindowLevelForKey(windowLevelKey))
            level = NSWindow.Level(rawValue: windowLevel)
            // `.managed` to keep window being within spaces(mission control) even if special window level
            collectionBehavior = .managed
        }
    }
}
