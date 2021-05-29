//
//  NSScrollView+Extensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/29.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Cocoa

extension NSScrollView {
    var isReachedToBottom: Bool {
        let viewRect = contentView.documentRect
        let visibleRect = contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")

        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 16

        let shouldScroll = (bottomY <= (offsetBottomY + allowance))
        return shouldScroll
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
