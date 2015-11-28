//
//  UserWindowController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// constant value for storyboard
private let kStoryboardNameUserWindowController = "UserWindowController"
private let kStoryboardIdUserWindowController = "UserWindowController"

protocol UserWindowControllerDelegate: class {
    func userWindowControllerDidClose(userWindowController: UserWindowController)
}

class UserWindowController: NSWindowController, NSWindowDelegate {
    // MARK: - Properties
    weak var delegate: UserWindowControllerDelegate?
    var userId: String? {
        didSet {
            self.reloadMessages()
        }
    }
    
    // MARK: - Object Lifecycle
    deinit {
        logger.debug("")
    }
    
    class func generateInstanceWithDelegate(delegate: UserWindowControllerDelegate?, userId: String) -> UserWindowController {
        let storyboard = NSStoryboard(name: kStoryboardNameUserWindowController, bundle: nil)
        let userWindowController = storyboard.instantiateControllerWithIdentifier(kStoryboardIdUserWindowController) as! UserWindowController
        
        userWindowController.delegate = delegate
        userWindowController.userId = userId
        
        return userWindowController
    }
    
    // MARK: - NSWindowDelegate Functions
    func windowWillClose(notification: NSNotification) {
        let window: AnyObject? = notification.object
        
        if window is UserWindow {
            self.delegate?.userWindowControllerDidClose(self)
        }
    }
    
    // MARK: - Public Functions
    func reloadMessages() {
        let userViewController = self.contentViewController as! UserViewController
        userViewController.userId = userId
    }
    
    // MARK: - Internal Functions
}
