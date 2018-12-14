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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
            self.selectText(self)
        })

        return result
    }
}
