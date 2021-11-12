//
//  NSScrollView+Extensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/29.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Cocoa

private let reachAllowance: CGFloat = 16

extension NSScrollView {
    var isReachedToTop: Bool {
        let offsetTopY = contentView.documentVisibleRect.origin.y + contentView.contentInsets.top
        // log.debug(offsetTopY)
        return offsetTopY - reachAllowance < 0
    }

    var isReachedToBottom: Bool {
        let viewRect = contentView.documentRect
        let visibleRect = contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")

        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height

        return bottomY <= (offsetBottomY + reachAllowance)
    }

    func scrollToTop() {
        contentView.setBoundsOrigin(NSPoint(x: _x, y: _minY))
        flashScrollers()
    }

    func scrollToBottom() {
        contentView.setBoundsOrigin(NSPoint(x: _x, y: _maxY))
        flashScrollers()
    }

    func scrollUp() {
        let y = max(
            contentView.documentVisibleRect.origin.y
                - contentView.documentVisibleRect.size.height
                + contentView.contentInsets.top,
            _minY)
        contentView.setBoundsOrigin(NSPoint(x: _x, y: y))
        flashScrollers()
    }

    func scrollDown() {
        let y = min(
            contentView.documentVisibleRect.origin.y
                + contentView.documentVisibleRect.size.height
                - contentView.contentInsets.top,
            _maxY)
        contentView.setBoundsOrigin(NSPoint(x: _x, y: y))
        flashScrollers()
    }
}

private extension NSScrollView {
    var _x: CGFloat { contentView.documentVisibleRect.origin.x }
    var _minY: CGFloat { -contentView.contentInsets.top }
    var _maxY: CGFloat { contentView.documentRect.size.height - contentView.documentVisibleRect.size.height }
}
