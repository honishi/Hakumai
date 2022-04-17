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

    func enableCornerRadius(_ radius: CGFloat = 4) {
        guard layer?.cornerRadius != radius else { return }
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.masksToBounds = true
    }
}

private let keyPathBackgroundColor = "backgroundColor"

extension NSView {
    func setBackgroundColor(_ color: NSColor?) {
        // https://stackoverflow.com/a/17795052/13220031
        wantsLayer = true
        layer?.backgroundColor = color?.cgColor
    }

    func flash(_ color: NSColor, duration: TimeInterval = 1) {
        cancelFlash()

        wantsLayer = true
        let animation = CABasicAnimation(keyPath: keyPathBackgroundColor)
        animation.fromValue = color.cgColor
        animation.toValue = NSColor.clear.cgColor
        animation.duration = duration
        layer?.add(animation, forKey: animation.keyPath)
    }

    func cancelFlash() {
        layer?.removeAnimation(forKey: keyPathBackgroundColor)
    }
}
