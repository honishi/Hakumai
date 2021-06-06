//
//  AuthWindowController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/20.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Cocoa

protocol AuthWindowControllerDelegate: AnyObject {
    func authWindowControllerDidLogin(_ authWindowController: AuthWindowController)
}

extension AuthWindowController {
    static func make(delegate: AuthWindowControllerDelegate?) -> AuthWindowController {
        let wc = StoryboardScene.AuthWindowController.authWindowController.instantiate()
        wc.delegate = delegate
        return wc
    }
}

final class AuthWindowController: NSWindowController {
    // MARK: - Properties
    private weak var delegate: AuthWindowControllerDelegate?

    private var authViewController: AuthViewController? { contentViewController as? AuthViewController }

    // MARK: - Object Lifecycle
    deinit { log.debug("deinit") }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
        authViewController?.setDelegate(self)
    }
}

extension AuthWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        log.debug("will close")
    }
}

extension AuthWindowController: AuthViewControllerDelegate {
    func authViewControllerDidLogin(_ authViewController: AuthViewController) {
        delegate?.authWindowControllerDidLogin(self)
    }
}

extension AuthWindowController {
    func startAuthorization() {
        authViewController?.startAuthorization()
    }
}
