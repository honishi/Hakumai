//
//  ScoreView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import QuartzCore

class ColoredView: NSView {
    var fillColor: NSColor = NSColor.grayColor() {
        didSet {
            layer?.setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        // calyer implementation based on http://rway.tumblr.com/post/4525503228
        let layer = CALayer()
        layer.delegate = self
        layer.bounds = bounds
        layer.needsDisplayOnBoundsChange = true
        layer.setNeedsDisplay()
        
        self.layer = layer
        wantsLayer = true
    }

    override func drawLayer(layer: CALayer, inContext ctx: CGContext) {
        CGContextSetFillColorWithColor(ctx, fillColor.CGColor)
        CGContextFillRect(ctx, bounds)
    }
    
    /*
    override func drawRect(dirtyRect: NSRect) {
        // http://stackoverflow.com/a/2962882
        fillColor.setFill()
        NSRectFill(dirtyRect);
        
        super.drawRect(dirtyRect)
    }
    */
}