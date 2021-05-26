//
//  NSView+Extensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/26.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Cocoa

extension NSView {
    func addBorder() {
        // use async to properly render border line. if not async, the line sometimes disappears
        DispatchQueue.main.async { self._addBorder() }
    }

    func _addBorder() {
        layer?.borderWidth = 0.5
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.black.cgColor
    }
}
