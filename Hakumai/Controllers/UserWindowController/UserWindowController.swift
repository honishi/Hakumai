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
    // swiftlint:disable function_parameter_count
    static func make(delegate: UserWindowControllerDelegate?, nicoManager: NicoManagerType, live: Live, messageContainer: MessageContainer, userId: String, handleName: String?) -> UserWindowController {
        let wc = StoryboardScene.UserWindowController.userWindowController.instantiate()
        wc.delegate = delegate
        wc.set(
            nicoManager: nicoManager,
            live: live,
            messageContainer: messageContainer,
            userId: userId,
            handleName: handleName
        )
        return wc
    }
    // swiftlint:enable function_parameter_count
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
    func set(nicoManager: NicoManagerType, live: Live, messageContainer: MessageContainer, userId: String, handleName: String?) {
        self.userId = userId
        let userName = nicoManager.cachedUserName(for: userId)
        window?.title = (handleName ?? userName ?? userId) + " (\(live.title))"
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.set(
            nicoManager: nicoManager,
            live: live,
            messageContainer: messageContainer,
            userId: userId,
            handleName: handleName
        )
    }

    func reloadMessages() {
        guard let userViewController = contentViewController as? UserViewController else { return }
        userViewController.reloadMessages()
    }
}
