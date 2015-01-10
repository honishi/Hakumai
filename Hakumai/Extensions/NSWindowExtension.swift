//
//  NSWindowExtension.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/15/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let kWindowLevelKeyForNormal = kCGNormalWindowLevelKey
private let kWindowLevelKeyForAlwaysOnTop = kCGFloatingWindowLevelKey

extension NSWindow {
    // http://qiita.com/rryu/items/04af65d772e81d2beb7a
    var alwaysOnTop: Bool {
        get {
            let windowLevelKey = Int32(kWindowLevelKeyForAlwaysOnTop)
            let windowLevel = Int(CGWindowLevelForKey(windowLevelKey))
            
            return self.level == windowLevel
        }
        
        set(newAlwaysOnTop) {
            let key = newAlwaysOnTop ? kWindowLevelKeyForAlwaysOnTop : kWindowLevelKeyForNormal
            
            let windowLevelKey = Int32(key)
            let windowLevel = Int(CGWindowLevelForKey(windowLevelKey))
            
            self.level = windowLevel
            
            // .Managed to keep window being within spaces(mission control) even if special window level
            self.collectionBehavior = .Managed
        }
    }
}
