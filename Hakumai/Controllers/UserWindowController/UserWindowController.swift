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
    private weak var delegate: UserWindowControllerDelegate?
    private(set) var userId: String = ""

    // MARK: - Object Lifecycle
    deinit {
        log.debug("")
    }
}

extension UserWindowController {
    static func make(delegate: UserWindowControllerDelegate?, userId: String, handleName: String?) -> UserWindowController {
        let wc = StoryboardScene.UserWindowController.userWindowController.instantiate()
        wc.delegate = delegate
        wc.set(userId: userId, handleName: handleName)
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
    func set(userId: String, handleName: String?) {
        self.userId = userId
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.set(userId: userId, handleName: handleName)
    }

    func reloadMessages() {
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.reloadMessages()
    }
}
