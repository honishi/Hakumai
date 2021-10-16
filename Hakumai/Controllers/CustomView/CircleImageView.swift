//
//  CircleImageView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/10/16.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class CircleImageView: NSImageView {
    override var frame: NSRect {
        didSet {
            super.frame = frame
            adjustCornerRadius()
        }
    }

    // Seems `override var bounds` is not called even when the size of image view changed.

    override func awakeFromNib() {
        configure()
    }
}

private extension CircleImageView {
    func configure() {
        adjustCornerRadius()
    }

    func adjustCornerRadius() {
        let targetRadius = min(bounds.width, bounds.height) / 2
        guard layer?.cornerRadius != targetRadius else { return }
        wantsLayer = true
        layer?.cornerRadius = targetRadius
        layer?.masksToBounds = true
    }
}
