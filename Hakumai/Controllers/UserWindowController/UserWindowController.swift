//
//  UserWindowController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

protocol UserWindowControllerDelegate: AnyObject {
    func userWindowControllerDidClose(_ userWindowController: UserWindowController)
}

final class UserWindowController: NSWindowController {
    // MARK: - Properties
    weak var delegate: UserWindowControllerDelegate?
    var userId: String? {
        didSet {
            reloadMessages()
        }
    }

    // MARK: - Object Lifecycle
    deinit {
        log.debug("")
    }
}

extension UserWindowController {
    static func make(delegate: UserWindowControllerDelegate?, userId: String) -> UserWindowController {
        let wc = StoryboardScene.UserWindowController.userWindowController.instantiate()
        wc.delegate = delegate
        wc.userId = userId
        return wc
    }
}

extension UserWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let window: Any? = notification.object
        if window is UserWindow {
            delegate?.userWindowControllerDidClose(self)
        }
    }
}

// MARK: - Public Functions
extension UserWindowController {
    func reloadMessages() {
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.userId = userId
    }
}
