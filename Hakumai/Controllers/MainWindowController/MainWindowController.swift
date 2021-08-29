//
//  MainWindowController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/9/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

protocol MainWindowControllerDelegate: AnyObject {
    func mainWindowControllerWillClose(_ mainWindowController: MainWindowController)
}

final class MainWindowController: NSWindowController {
    // MARK: - Properties
    private weak var delegate: MainWindowControllerDelegate?

    // MARK: - NSWindowController Overrides
    override func windowDidLoad() {
        super.windowDidLoad()

        // autosave name setting in IB does not work properly, so set it manually.
        // - https://sites.google.com/site/xcodecodingmemo/home/mac-app-memo/resume-window-size-and-position
        // - http://d.hatena.ne.jp/RNatori/20070913
        windowFrameAutosaveName = "MainWindow"

        applyAlwaysOnTop()
    }
}

extension MainWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // XXX: Consider whther we should call disconnect call at deinit in NicoUtility?
        mainViewController.disconnect()
        delegate?.mainWindowControllerWillClose(self)
    }
}

extension MainWindowController {
    static func make(delegate: MainWindowControllerDelegate?) -> MainWindowController {
        let wc = StoryboardScene.MainWindowController.mainWindowController.instantiate()
        wc.delegate = delegate
        return wc
    }
}

extension MainWindowController {
    func login() {
        mainViewController.login()
    }

    func logout() {
        mainViewController.logout()
    }

    func focusLiveTextField() {
        mainViewController.focusLiveTextField()
    }

    func grabUrlFromBrowser() {
        mainViewController.grabUrlFromBrowser(self)
    }

    func focusCommentTextField() {
        mainViewController.focusCommentTextField()
    }

    func toggleSpeech() {
        mainViewController.toggleSpeech()
    }

    func toggleCommentAnonymouslyButtonState() {
        mainViewController.toggleCommentAnonymouslyButtonState()
    }

    func setVoiceVolume(_ volume: Int) {
        mainViewController.setVoiceVolume(volume)
    }

    func changeEnableMuteUserIds(_ enabled: Bool) {
        mainViewController.changeEnableMuteUserIds(enabled)
    }

    func changeMuteUserIds(_ muteUserIds: [[String: String]]) {
        mainViewController.changeMuteUserIds(muteUserIds)
    }

    func changeEnableMuteWords(_ enabled: Bool) {
        mainViewController.changeEnableMuteWords(enabled)
    }

    func changeMuteWords(_ muteWords: [[String: String]]) {
        mainViewController.changeMuteWords(muteWords)
    }

    func changeFontSize(_ fontSize: Float) {
        mainViewController.changeFontSize(fontSize)
    }
}

private extension MainWindowController {
    // swiftlint:disable force_cast
    var mainViewController: MainViewController { contentViewController as! MainViewController }
    // swiftlint:enable force_cast

    func applyAlwaysOnTop() {
        let alwaysOnTop = UserDefaults.standard.bool(forKey: Parameters.alwaysOnTop)
        window?.alwaysOnTop = alwaysOnTop
    }
}
