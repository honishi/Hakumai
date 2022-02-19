//
//  PointingHandButton.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/19.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class PointingHandButton: NSButton {
    override func awakeFromNib() {
        configure()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

private extension PointingHandButton {
    func configure() {
        bezelStyle = .texturedRounded
        isBordered = false
        title = ""
    }
}
