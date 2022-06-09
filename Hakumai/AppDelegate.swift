//
//  AppDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import Kingfisher

private let mainWindowDefaultTopLeftPoint = NSPoint(x: 100, y: 100)
private let urlObservationIgnoreSeconds: TimeInterval = 120

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    struct IgnoreLive {
        let untilDate: Date
        let liveProgramId: String
    }

    @IBOutlet weak var speakMenuItem: NSMenuItem!

    private let notificationPresenter: NotificationPresenterProtocol = NotificationPresenter.default

    private var mainWindowControllers: [MainWindowController] = []
    private var nextMainWindowTopLeftPoint: NSPoint = NSPoint.zero

    private let browserUrlObserver: BrowserUrlObserverType = BrowserUrlObserver()
    private var ignoreLives: [IgnoreLive] = []
    private var enableBrowerTabSelectionSync = false

    // MARK: - NSApplicationDelegate Functions
    func applicationDidFinishLaunching(_ notification: Notification) {
        LoggerHelper.setupLogger(log)
        migrateApplicationVersion()
        initializeUserDefaults()
        addObserverForUserDefaults()
        configureMenuItems()
        configureNotificationPresenter()
        configureAndClearImageCache()
        debugPrintToken()
        openNewWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: Menu Handlers
extension AppDelegate {
    @IBAction func login(_ sender: Any) {
        activeMainWindowController?.login()
    }

    @IBAction func logout(_ sender: Any) {
        activeMainWindowController?.logout()
    }

    @IBAction func openNewWindow(_ sender: Any) {
        openNewWindow()
    }

    @IBAction func openNewTab(_ sender: Any) {
        openNewTab()
    }

    @IBAction func closeWindow(_ sender: Any) {
        closeWindow()
    }

    @IBAction func openPreferences(_ sender: AnyObject) {
        PreferenceWindowController.shared.showWindow(self)
    }

    @IBAction func openUrl(_ sender: AnyObject) {
        activeMainWindowController?.focusLiveTextField()
    }

    @IBAction func grabUrlFromChrome(_ sender: AnyObject) {
        activeMainWindowController?.grabUrlFromBrowser()
    }

    @IBAction func newComment(_ sender: AnyObject) {
        activeMainWindowController?.focusCommentTextField()
    }

    @IBAction func toggleCommentAnonymously(_ sender: Any) {
        activeMainWindowController?.toggleCommentAnonymouslyButtonState()
    }

    @IBAction func toggleSpeech(_ sender: Any) {
        activeMainWindowController?.toggleSpeech()
    }

    @IBAction func zoomDefault(_ sender: AnyObject) {
        setFontSize(kDefaultFontSize)
    }

    @IBAction func zoomIn(_ sender: AnyObject) {
        incrementFontSize(1)
    }

    @IBAction func zoomOut(_ sender: AnyObject) {
        incrementFontSize(-1)
    }

    // here no handlers for 'Always On Top' menu item. it should be implemented using KVO.
    // see details at http://stackoverflow.com/a/13613507
}

// MARK: KVO Functions
extension AppDelegate {
    // swiftlint:disable block_based_kvo cyclomatic_complexity
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // log.debug("detected observing value changed: key:[\(keyPath)], change:[\(change)]")
        guard let keyPath = keyPath, let change = change else { return }

        switch (keyPath, change[.newKey]) {
        case (Parameters.browserInUse, let changed as Int):
            log.debug("browserInUse -> \(changed)")
            guard let browser = BrowserInUseType(rawValue: changed) else { return }
            browserUrlObserver.setBrowserType(browser)

        case (Parameters.commentSpeechVolume, let changed as Int):
            mainWindowControllers.forEach { $0.setVoiceVolume(changed) }

        case (Parameters.commentSpeechVoicevoxSpeaker, let changed as Int):
            mainWindowControllers.forEach { $0.setVoiceSpeaker(changed) }

        case (Parameters.enableMuteUserIds, let changed as Bool):
            mainWindowControllers.forEach { $0.changeEnableMuteUserIds(changed) }

        case (Parameters.muteUserIds, let changed as [[String: String]]):
            mainWindowControllers.forEach { $0.changeMuteUserIds(changed) }

        case (Parameters.enableMuteWords, let changed as Bool):
            mainWindowControllers.forEach { $0.changeEnableMuteWords(changed) }

        case (Parameters.muteWords, let changed as [[String: String]]):
            mainWindowControllers.forEach { $0.changeMuteWords(changed) }

        case (Parameters.fontSize, let changed as Float):
            mainWindowControllers.forEach { $0.changeFontSize(changed) }

        case (Parameters.alwaysOnTop, let newValue as Bool):
            makeWindowsAlwaysOnTop(newValue)

        case (Parameters.enableBrowserUrlObservation, let newValue as Bool):
            setBrowserUrlObservation(newValue)

        case (Parameters.enableBrowserTabSelectionSync, let newValue as Bool):
            enableBrowerTabSelectionSync = newValue
            log.debug("enableBrowerTabSelectionSync = \(enableBrowerTabSelectionSync)")

        case (Parameters.enableEmotionMessage, let newValue as Bool):
            mainWindowControllers.forEach { $0.changeEnableEmotionMessage(newValue) }

        case (Parameters.enableDebugMessage, let newValue as Bool):
            mainWindowControllers.forEach { $0.changeEnableDebugMessage(newValue) }

        default:
            break
        }
    }
    // swiftlint:enable block_based_kvo cyclomatic_complexity
}

// MARK: BrowserUrlObserverDelegate Methods
extension AppDelegate: BrowserUrlObserverDelegate {
    func browserUrlObserver(_ browserUrlObserver: BrowserUrlObserverType, didGetUrl liveUrl: URL) {
        // log.debug(liveUrl)
        guard let liveProgramId = liveUrl.absoluteString.extractLiveProgramId() else {
            return
        }
        // 1. Already connected in exsiting windows?
        if isConnected(url: liveUrl) {
            log.debug("Already connected. (\(liveProgramId))")
            focusWindowIfNeeded(liveProgramId: liveProgramId)
            return
        }
        // 2. Update ignore-url list. Skip live if matched.
        refreshIgnoreLives()
        let shouldIgnore = ignoreLives.map({ $0.liveProgramId }).contains(liveProgramId)
        if shouldIgnore {
            log.debug("Live is recently opened, so skip. (\(liveProgramId))")
            return
        }
        ignoreLive(liveProgramId: liveProgramId, seconds: urlObservationIgnoreSeconds)
        // 3. Is active window empty and can be used?
        if activeMainWindowController?.hasNeverBeenConnected == true {
            activeMainWindowController?.connectToUrl(liveUrl)
            return
        }
        // 4. Any other available window for the live?
        if let wc = mainWindowControllers
            .filter({ $0.liveProgramIdInUrlTextField == liveProgramId })
            .first {
            wc.connectToUrl(liveUrl)
            return
        }
        // 5. No available existing windows, open the new window.
        let commentInputInProgress = mainWindowControllers
            .map { $0.commentInputInProgress }
            .contains(true)
        let wc = openNewTab(selectTab: !commentInputInProgress)
        wc?.connectToUrl(liveUrl)
    }

    private func isConnected(url: URL) -> Bool {
        let liveProgramId = url.absoluteString.extractLiveProgramId()
        return mainWindowControllers.map { $0.live?.liveProgramId }.contains(liveProgramId)
    }

    private func focusWindowIfNeeded(liveProgramId: String) {
        // 1. Enabled by setting?
        guard enableBrowerTabSelectionSync else {
            log.debug("Browser tab selection sync is NOT enabled. (\(liveProgramId))")
            return
        }
        // 2. Is window on active space?
        let isOnActiveSpace = mainWindowControllers
            .map { $0.window }
            .compactMap { $0 }
            .sorted { $0.orderedIndex < $1.orderedIndex }
            .first?
            .isOnActiveSpace ?? false
        guard isOnActiveSpace else {
            log.debug("MainWindow is NOT on active space. Skip. (\(liveProgramId))")
            return
        }
        // 3. Is window other than MainWindow presenting?
        let visibleAppWindows = NSApp.windows.filter({ $0.isVisible })
        let windowsOtherThanMainWidnow = visibleAppWindows.filter({ !($0 is MainWindow) })
        if !windowsOtherThanMainWidnow.isEmpty {
            log.debug("Window except for MainWindow is presenting. Skip. (\(liveProgramId))")
            return
        }
        // 4. Has MainWindow focus?
        if activeMainWindowController?.window?.isMainWindow == true {
            log.debug("MainWindow has focus. Skip. (\(liveProgramId))")
            return
        }
        // 5. Ok, set focus to window, if possible.
        let wc = mainWindowControllers
            .filter({ $0.isLiveProgramId(liveProgramId) })
            .first
        if let wc = wc {
            log.debug("Show MainWindow. (\(liveProgramId))")
            wc.showWindow(self)
        }
    }
}

private extension AppDelegate {
    func ignoreLive(liveProgramId: String, seconds: TimeInterval) {
        ignoreLives.append(
            IgnoreLive(
                untilDate: Date().addingTimeInterval(seconds),
                liveProgramId: liveProgramId
            )
        )
    }

    func refreshIgnoreLives() {
        let origin = Date()
        ignoreLives = ignoreLives
            .filter { $0.untilDate.timeIntervalSince(origin) > 0 }
        // log.debug(ignoreLives)
    }
}

// MARK: Application Initialize Utility
private extension AppDelegate {
    func migrateApplicationVersion() {
        let defaults = UserDefaults.standard

        let lastVerInDefaults = defaults.string(forKey: Parameters.lastLaunchedApplicationVersion)
        guard let currentVer = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            log.error("fatal: cannot retieve application version..")
            return
        }
        log.info("last launched app version:[\(lastVerInDefaults ?? "")] current app version:[\(currentVer)]")

        guard let lastVer = lastVerInDefaults else {
            log.info("detected app first launch, no need to migrate application version")
            saveLastLauncheApplicationVersion(currentVer)
            return
        }

        guard let lastVerInt = Int(lastVer), let currentVerInt = Int(currentVer) else {
            log.error("fatal: cannot convert version string into int..")
            return
        }

        if lastVerInt < currentVerInt {
            // do some app version migration here
            log.info("detected app version up from:[\(lastVerInt)] to:[\(currentVerInt)]")

            // version migration sample
            /* if lastVersionNumber < 3 {
             defaults.removeObjectForKey(Parameters.MuteUserIds)
             defaults.removeObjectForKey(Parameters.MuteWords)
             defaults.synchronize()
             } */
        }

        saveLastLauncheApplicationVersion(currentVer)
    }

    func saveLastLauncheApplicationVersion(_ version: String) {
        let defaults = UserDefaults.standard
        defaults.set(version, forKey: Parameters.lastLaunchedApplicationVersion)
        defaults.synchronize()
    }

    func initializeUserDefaults() {
        let defaults: [String: Any] = [
            Parameters.browserInUse: BrowserInUseType.chrome.rawValue,
            Parameters.fontSize: kDefaultFontSize,
            Parameters.commentSpeechVolume: 100,
            Parameters.commentSpeechVoicevoxSpeaker: 0,
            Parameters.enableMuteUserIds: true,
            Parameters.enableMuteWords: true,
            Parameters.alwaysOnTop: false,
            Parameters.commentAnonymously: true,
            Parameters.enableBrowserUrlObservation: false,
            Parameters.enableBrowserTabSelectionSync: false,
            Parameters.enableLiveNotification: false,
            Parameters.enableEmotionMessage: true,
            Parameters.enableDebugMessage: false]
        UserDefaults.standard.register(defaults: defaults)
    }

    func addObserverForUserDefaults() {
        let keyPaths = [
            // general
            Parameters.browserInUse,
            Parameters.commentSpeechVolume,
            Parameters.commentSpeechVoicevoxSpeaker,
            // mute
            Parameters.enableMuteUserIds, Parameters.muteUserIds,
            Parameters.enableMuteWords, Parameters.muteWords,
            // misc
            Parameters.fontSize,
            Parameters.alwaysOnTop,
            Parameters.enableBrowserUrlObservation,
            Parameters.enableBrowserTabSelectionSync,
            Parameters.enableEmotionMessage,
            Parameters.enableDebugMessage
        ]
        for keyPath in keyPaths {
            UserDefaults.standard.addObserver(
                self, forKeyPath: keyPath, options: [.initial, .new], context: nil)
        }
    }

    func configureMenuItems() {
        if #available(macOS 10.14, *) {
            speakMenuItem.isHidden = false
        } else {
            speakMenuItem.isHidden = true
        }
    }

    func configureNotificationPresenter() {
        notificationPresenter.configure()
        notificationPresenter.notificationClicked = { [weak self] in
            self?.showWindow(for: $0)
        }
    }

    func configureAndClearImageCache() {
        // Default cache behavior:
        // "Images in memory storage will expire after 5 minutes from
        // last accessed, while it is a week for images in disk storage."
        // https://github.com/onevcat/Kingfisher/wiki/Cheat-Sheet#set-default-expiration-for-cache
        let cache = KingfisherManager.shared.cache
        cache.diskStorage.config.expiration = .seconds(60 * 60 * 12)    // 12 hours
        cache.clearCache {
            log.debug("Disk cache for images has been cleared.")
        }
    }
}

// MARK: Multi-Window Management
extension AppDelegate {
    var activeMainWindowController: MainWindowController? {
        let keyWindowWc = mainWindowControllers.filter { $0.window?.isKeyWindow == true }.first
        return keyWindowWc ?? mainWindowControllers.first
    }

    var lastTabbedWindow: NSWindow? {
        let activeWindow = activeMainWindowController?.window
        return activeWindow?.tabbedWindows?.last ?? activeWindow
    }
}

extension AppDelegate: MainWindowControllerDelegate {
    func mainWindowControllerRequestNewTab(_ mainWindowController: MainWindowController) {
        openNewTab()
    }

    func mainWindowControllerWillClose(_ mainWindowController: MainWindowController) {
        if let liveProgramId = mainWindowController.live?.liveProgramId {
            ignoreLive(liveProgramId: liveProgramId, seconds: urlObservationIgnoreSeconds)
        }
        mainWindowControllers.removeAll { $0 == mainWindowController }
        log.debug(mainWindowControllers)
    }

    func mainWindowControllerSpeechEnabledChanged(_ mainWindowController: MainWindowController, isEnabled: Bool) {
        log.debug(isEnabled)
        guard isEnabled else { return }
        let otherMainWindowControllers = mainWindowControllers.filter { $0 !== mainWindowController }
        otherMainWindowControllers.forEach { $0.setSpeechEnabled(false) }
    }
}

private extension AppDelegate {
    func openNewWindow() {
        let wc = MainWindowController.make(delegate: self)
        // If the window is NOT first one, then adjust position and size based on first one.
        if let firstWindow = mainWindowControllers.first?.window, let newWindow = wc.window {
            let rect = NSRect(origin: mainWindowDefaultTopLeftPoint, size: firstWindow.frame.size)
            newWindow.setFrame(rect, display: false)
            nextMainWindowTopLeftPoint = newWindow.cascadeTopLeft(from: nextMainWindowTopLeftPoint)
        }
        mainWindowControllers.append(wc)
        wc.showWindow(self)
        log.debug(mainWindowControllers)
    }

    @discardableResult
    func openNewTab(selectTab: Bool = true) -> MainWindowController? {
        let wc = MainWindowController.make(delegate: self)
        guard let newWindow = wc.window,
              let lastWindow = lastTabbedWindow else { return nil }
        lastWindow.addTabbedWindow(newWindow, ordered: .above)
        if selectTab, lastWindow.isOnActiveSpace {
            wc.showWindow(self)
        }
        mainWindowControllers.append(wc)
        log.debug(mainWindowControllers)
        return wc
    }

    func closeWindow() {
        guard let window = NSApplication.shared.keyWindow else { return }
        window.close()
    }

    func mainWindowController(for liveProgramId: String) -> MainWindowController? {
        return mainWindowControllers.filter { $0.isLiveProgramId(liveProgramId) }.first
    }

    func showWindow(for liveProgramId: String) {
        mainWindowController(for: liveProgramId)?.showWindow(self)
    }
}

// MARK: Misc
private extension AppDelegate {
    func makeWindowsAlwaysOnTop(_ alwaysOnTop: Bool) {
        mainWindowControllers.forEach {
            $0.window?.alwaysOnTop = alwaysOnTop
        }
        log.debug("changed always on top: \(alwaysOnTop)")
    }

    func incrementFontSize(_ increment: Float) {
        setFontSize(UserDefaults.standard.float(forKey: Parameters.fontSize) + increment)
    }

    func setFontSize(_ fontSize: Float) {
        guard kMinimumFontSize...kMaximumFontSize ~= fontSize else { return }
        UserDefaults.standard.set(fontSize, forKey: Parameters.fontSize)
        UserDefaults.standard.synchronize()
    }

    func setBrowserUrlObservation(_ isEnabled: Bool) {
        log.debug("changed browser url observation: \(isEnabled)")
        if isEnabled {
            browserUrlObserver.start(delegate: self)
        } else {
            browserUrlObserver.stop()
        }
    }
}

// MARK: Debug Methods
private extension AppDelegate {
    func debugPrintToken() {
        log.debug("accessToken: " + (AuthManager.shared.currentToken?.accessToken ?? "-"))
        log.debug("expireIn: " + String((AuthManager.shared.currentToken?.expiresIn ?? 0)))
        log.debug("refreshToken: " + (AuthManager.shared.currentToken?.refreshToken ?? "-"))
    }
}
