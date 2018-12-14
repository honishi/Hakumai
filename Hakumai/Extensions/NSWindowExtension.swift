//
//  NSWindowExtension.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/15/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let kWindowLevelKeyForNormal = CGWindowLevelKey.normalWindow
private let kWindowLevelKeyForAlwaysOnTop = CGWindowLevelKey.floatingWindow

extension NSWindow {
    // http://qiita.com/rryu/items/04af65d772e81d2beb7a
    var alwaysOnTop: Bool {
        get {
            let windowLevel = Int(CGWindowLevelForKey(kWindowLevelKeyForAlwaysOnTop))
            return level.rawValue == windowLevel
        }
        
        set(newAlwaysOnTop) {
            let windowLevelKey = newAlwaysOnTop ? kWindowLevelKeyForAlwaysOnTop : kWindowLevelKeyForNormal
            let windowLevel = Int(CGWindowLevelForKey(windowLevelKey))
            
            level = convertToNSWindowLevel(windowLevel)
            
            // .Managed to keep window being within spaces(mission control) even if special window level
            collectionBehavior = .managed
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSWindowLevel(_ input: Int) -> NSWindow.Level {
	return NSWindow.Level(rawValue: input)
}
