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
    func userWindowControllerDidClose(_ userWindowController: UserWindowController)
}

final class UserWindowController: NSWindowController, NSWindowDelegate {
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

    static func generateInstance(delegate: UserWindowControllerDelegate?, userId: String) -> UserWindowController? {
        let storyboard = NSStoryboard(name: kStoryboardNameUserWindowController, bundle: nil)
        guard let userWindowController = storyboard.instantiateController(withIdentifier: kStoryboardIdUserWindowController) as? UserWindowController else {
            return nil
        }

        userWindowController.delegate = delegate
        userWindowController.userId = userId

        return userWindowController
    }

    // MARK: - NSWindowDelegate Functions
    func windowWillClose(_ notification: Notification) {
        let window: Any? = notification.object

        if window is UserWindow {
            delegate?.userWindowControllerDidClose(self)
        }
    }

    // MARK: - Public Functions
    func reloadMessages() {
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.userId = userId
    }

    // MARK: - Internal Functions
}
