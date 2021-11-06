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
        let x = contentView.documentVisibleRect.origin.x
        let y = contentView.contentInsets.top * -1
        let origin = NSPoint(x: x, y: y)

        contentView.setBoundsOrigin(origin)
    }

    func scrollToBottom() {
        let x = contentView.documentVisibleRect.origin.x
        let y = contentView.documentRect.size.height - contentView.documentVisibleRect.size.height
        let origin = NSPoint(x: x, y: y)

        // note: do not use scrollRowToVisible here.
        // scroll will be sometimes stopped when very long comment arrives.
        // tableView.scrollRowToVisible(tableView.numberOfRows - 1)
        contentView.setBoundsOrigin(origin)
    }
}
