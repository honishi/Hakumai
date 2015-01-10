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
    // also see more detailed note in HandleNameAddViewController's propery
    dynamic var muteValue: NSString!
    
    var completion: ((cancelled: Bool, muteValue: String?) -> Void)?
    
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
    @IBAction func addMute(sender: AnyObject) {
        if !(0 < self.muteValue.length) {
            return
        }
        
        if self.completion != nil {
            self.completion!(cancelled: false, muteValue: self.muteValue)
        }
    }
    
    @IBAction func cancelAddMute(sender: AnyObject) {
        if self.completion != nil {
            self.completion!(cancelled: true, muteValue: nil)
        }
    }
}