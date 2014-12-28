//
//  MuteAddViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/28/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import XCGLogger

class MuteAddViewController: NSViewController {
    // MARK: - Properties
    // this property contains mute target value, and is also used binding between text filed and add button.
    // http://stackoverflow.com/a/24017991
    var muteStringValue: String!
    
    var completion: ((cancelled: Bool, muteStringValue: String?) -> Void)?
    
    private let log = XCGLogger.defaultInstance()

    // MARK: - Object Lifecycle
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        log.debug("")
    }
    
    // MARK: - Internal Functions
    // MARK: Button Handlers
    @IBAction func detectedEnterInTextField(sender: AnyObject) {
        if 0 < countElements((sender as NSTextField).stringValue) {
            self.addMute(self)
        }
    }
    
    @IBAction func addMute(sender: AnyObject) {
        if self.completion != nil {
            self.completion!(cancelled: false, muteStringValue: self.muteStringValue)
        }
    }
    
    @IBAction func cancelAddMute(sender: AnyObject) {
        if self.completion != nil {
            self.completion!(cancelled: true, muteStringValue: nil)
        }
    }
}