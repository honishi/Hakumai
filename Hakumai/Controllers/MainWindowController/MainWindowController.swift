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
    func mainWindowControllerRequestNewTab(_ mainWindowController: MainWindowController)
    func mainWindowControllerWillClose(_ mainWindowController: MainWindowController)
    func mainWindowControllerSpeechEnabledChanged(_ mainWindowController: MainWindowController, isEnabled: Bool)
}

final class MainWindowController: NSWindowController {
    // MARK: - Properties
    private weak var delegate: MainWindowControllerDelegate?

    private var kusaTimer: Timer?

    // MARK: - NSWindowController Overrides
    override func windowDidLoad() {
        super.windowDidLoad()

        // autosave name setting in IB does not work properly, so set it manually.
        // - https://sites.google.com/site/xcodecodingmemo/home/mac-app-memo/resume-window-size-and-position
        // - http://d.hatena.ne.jp/RNatori/20070913
        windowFrameAutosaveName = "MainWindow"

        setInitialWindowTabTitle()
        applyAlwaysOnTop()
        window?.isMovableByWindowBackground = true
    }

    override func newWindowForTab(_ sender: Any?) {
        delegate?.mainWindowControllerRequestNewTab(self)
    }

    deinit { log.debug("deinit") }
}

extension MainWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // XXX: Consider whther we should call disconnect call at deinit in NicoManager?
        mainViewController.disconnect()
        delegate?.mainWindowControllerWillClose(self)
    }
}

extension MainWindowController: MainViewControllerDelegate {
    func mainViewControllerDidPrepareLive(_ mainViewController: MainViewController, title: String, community: String) {
        setLiveTitle(title: title, community: community, isConnected: true, isKusa: false)
    }

    func mainViewControllerDidDisconnect(_ mainViewController: MainViewController, title: String, community: String) {
        invalidateKusaTimer()
        setLiveTitle(title: title, community: community, isConnected: false, isKusa: false)
    }

    func mainViewControllerSpeechEnabledChanged(_ mainViewController: MainViewController, isEnabled: Bool) {
        delegate?.mainWindowControllerSpeechEnabledChanged(self, isEnabled: isEnabled)
    }

    func mainViewControllerDidDetectKusa(_ mainViewController: MainViewController, title: String, community: String) {
        invalidateKusaTimer()
        setLiveTitle(title: title, community: community, isConnected: true, isKusa: true)
        kusaTimer = Timer.scheduledTimer(
            withTimeInterval: 5,
            repeats: false,
            block: { [weak self] _ in
                self?.setLiveTitle(title: title, community: community, isConnected: true, isKusa: false)
            })
    }

    private func setLiveTitle(title: String, community: String, isConnected: Bool, isKusa: Bool) {
        let _title = "\(title) - \(community)"
        let _tabTitle = [
            isConnected ? "⚡️" : nil,
            isKusa ? "🌿" : nil,
            title
        ].compactMap({ $0 }).joined(separator: " ")
        setWindowTitle(_title, tabTitle: _tabTitle, tabToolTip: _title)
    }

    private func invalidateKusaTimer() {
        kusaTimer?.invalidate()
        kusaTimer = nil
    }
}

extension MainWindowController {
    static func make(delegate: MainWindowControllerDelegate?) -> MainWindowController {
        let wc = StoryboardScene.MainWindowController.mainWindowController.instantiate()
        wc.delegate = delegate
        wc.mainViewController.delegate = wc
        return wc
    }
}

extension MainWindowController {
    func isLiveProgramId(_ liveProgramId: String) -> Bool {
        mainViewController.live?.liveProgramId == liveProgramId
    }

    func login() {
        mainViewController.login()
    }

    func logout() {
        mainViewController.logout()
    }

    var live: Live? { mainViewController.live }

    var hasNeverBeenConnected: Bool { mainViewController.hasNeverBeenConnected }

    var commentInputInProgress: Bool { mainViewController.commentInputInProgress }

    var liveProgramIdInUrlTextField: String? { mainViewController.liveProgramIdInUrlTextField }

    func connectToUrl(_ url: URL) {
        mainViewController.connectToUrl(url)
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

    func setSpeechEnabled(_ isEnabled: Bool) {
        mainViewController.setSpeechEnabled(isEnabled)
    }

    func setVoiceVolume(_ volume: Int) {
        mainViewController.setVoiceVolume(volume)
    }

    func setVoiceSpeaker(_ speaker: Int) {
        mainViewController.setVoiceSpeaker(speaker)
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

    func changeEnableEmotionMessage(_ enabled: Bool) {
        mainViewController.changeEnableEmotionMessage(enabled)
    }

    func changeEnableDebugMessage(_ enabled: Bool) {
        mainViewController.changeEnableDebugMessage(enabled)
    }
}

private extension MainWindowController {
    // swiftlint:disable force_cast
    var mainViewController: MainViewController { contentViewController as! MainViewController }
    // swiftlint:enable force_cast

    func setInitialWindowTabTitle() {
        setWindowTitle(L10n.newLive, tabTitle: L10n.newLive)
    }

    func applyAlwaysOnTop() {
        let alwaysOnTop = UserDefaults.standard.bool(forKey: Parameters.alwaysOnTop)
        window?.alwaysOnTop = alwaysOnTop
    }

    func setWindowTitle(_ title: String, tabTitle: String, tabToolTip: String? = nil) {
        window?.title = title
        guard #available(macOS 10.13, *) else { return }
        window?.tab.title = tabTitle
        window?.tab.toolTip = tabToolTip
    }
}
