//
//  ScoreView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class ColoredView: NSView {
    var fillColor: NSColor = NSColor.grayColor()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // TODO: should implement wantslayer, see http://rway.tumblr.com/post/4525503228
    override func drawRect(dirtyRect: NSRect) {
        // http://stackoverflow.com/a/2962882
        self.fillColor.setFill()
        NSRectFill(dirtyRect);
        
        super.drawRect(dirtyRect)
    }
}