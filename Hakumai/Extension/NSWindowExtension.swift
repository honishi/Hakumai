//
//  NSWindowExtension.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/15/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

extension NSWindow {
    // http://qiita.com/rryu/items/04af65d772e81d2beb7a
    var alwaysOnTop: Bool {
        get {
            let windowLevelKey = Int32(kCGStatusWindowLevelKey)
            let windowLevel = Int(CGWindowLevelForKey(windowLevelKey))
            
            return self.level == windowLevel
        }
        
        set(newAlwaysOnTop) {
            let key = newAlwaysOnTop ? kCGStatusWindowLevelKey : kCGNormalWindowLevelKey
            
            let windowLevelKey = Int32(key)
            let windowLevel = Int(CGWindowLevelForKey(windowLevelKey))
            
            self.level = windowLevel
        }
    }
}
