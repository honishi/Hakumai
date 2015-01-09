//
//  MainTextField.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/10/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// based on codes http://stackoverflow.com/a/2196751
class MainTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        
        // need some delay here to wait for completion of focus animation
        let delay = 0.4 * Double(NSEC_PER_SEC)
        let time  = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue()) {
            self.selectText(self)
        }
        
        return result
    }
}
