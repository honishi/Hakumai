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
    func userWindowControllerWillClose(_ userWindowController: UserWindowController)
}

final class UserWindowController: NSWindowController {
    // MARK: - Properties
    private weak var delegate: UserWindowControllerDelegate?
    private(set) var userId: String = ""

    // MARK: - Object Lifecycle
    deinit {
        log.debug("")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.isMovableByWindowBackground = true
    }
}

extension UserWindowController {
    static func make(delegate: UserWindowControllerDelegate?, nicoUtility: NicoUtility, messageContainer: MessageContainer, userId: String, handleName: String?) -> UserWindowController {
        let wc = StoryboardScene.UserWindowController.userWindowController.instantiate()
        wc.delegate = delegate
        wc.set(nicoUtility: nicoUtility, messageContainer: messageContainer, userId: userId, handleName: handleName)
        return wc
    }
}

extension UserWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let window: Any? = notification.object
        if window is UserWindow {
            delegate?.userWindowControllerWillClose(self)
        }
    }
}

// MARK: - Public Functions
extension UserWindowController {
    func set(nicoUtility: NicoUtility, messageContainer: MessageContainer, userId: String, handleName: String?) {
        self.userId = userId
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.set(nicoUtility: nicoUtility, messageContainer: messageContainer, userId: userId, handleName: handleName)
    }

    func reloadMessages() {
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.reloadMessages()
    }
}
