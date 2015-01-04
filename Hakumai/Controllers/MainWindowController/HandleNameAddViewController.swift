//
//  HandleNameAddViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import XCGLogger

class HandleNameAddViewController: NSViewController {
    // MARK: - Properties
    // this property contains handle name value, and is also used binding between text filed and add button.
    // http://stackoverflow.com/a/24017991
    // and use `dynamic` to make binding work properly. see details at the following link
    // - https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CocoaBindings/Concepts/Troubleshooting.html
    //     - Changing the value in the user interface programmatically is not reflected in the model
    //     - Changing the value of a model property programmatically is not reflected in the user interface
    // - http://stackoverflow.com/a/26564912
    // also use NSString instead of String, cause .length property is used in button's enabled binding.
    dynamic var handleName: NSString = ""
    
    var completion: ((cancelled: Bool, handleName: String?) -> Void)?

    private let log = XCGLogger.defaultInstance()
    
    // MARK: - Object Lifecycle
    deinit {
        log.debug("")
    }

    // MARK: - Internal Functions
    @IBAction func addHandleName(sender: AnyObject) {
        if !(0 < self.handleName.length) {
            return
        }
        
        if self.completion != nil {
            self.completion!(cancelled: false, handleName: self.handleName)
        }
    }
    
    @IBAction func cancelToAdd(sender: AnyObject) {
        if self.completion != nil {
            self.completion!(cancelled: true, handleName: nil)
        }
    }
}