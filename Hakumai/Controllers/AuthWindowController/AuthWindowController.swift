//
//  AuthWindowController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/20.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Cocoa

extension AuthWindowController {
    static func make() -> AuthWindowController {
        let wc = StoryboardScene.AuthWindowController.authWindowController.instantiate()
        return wc
    }
}

final class AuthWindowController: NSWindowController {
    deinit { log.debug("deinit") }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }
}

extension AuthWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        log.debug("will close")
    }
}

extension AuthWindowController {
    func startAuthorization() {
        guard let vc = contentViewController as? AuthViewController else { return }
        vc.startAuthorization()
    }
}
