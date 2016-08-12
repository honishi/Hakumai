//
//  PreferenceWindow.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/15/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class PreferenceWindow: NSWindow {
    // MARK: - NSObject Overrides
    override func awakeFromNib() {
        super.awakeFromNib()
        // alwaysOnTop = true
    }

    // MARK: - NSResponder Overrides
    // http://genjiapp.com/blog/2012/10/25/how-to-develop-a-preferences-window-for-os-x-app.html
    override func cancelOperation(_ sender: AnyObject?) {
        close()
    }
}
