//
//  LayeredClipView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/3/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class LayeredClipView: NSClipView {
    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.enableScrollLayer()
    }

    func enableScrollLayer() {
        self.layer = CAScrollLayer()
        self.wantsLayer = true
        // self.layerContentsRedrawPolicy = .Never
        self.layerContentsRedrawPolicy = .OnSetNeedsDisplay
    }
}