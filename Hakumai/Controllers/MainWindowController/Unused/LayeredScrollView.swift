//
//  LayeredScrollView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/3/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class LayeredScrollView: NSScrollView {
    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        
        enableLayer()
    }
    
    func enableLayer() {
        wantsLayer = true
    }
}