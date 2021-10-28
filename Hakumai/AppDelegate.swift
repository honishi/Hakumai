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

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var speakMenuItem: NSMenuItem!

    private var mainWindowControllers: [MainWindowController] = []
    private var nextMainWindowTopLeftPoint: NSPoint = NSPoint.zero

    // MARK: - NSApplicationDelegate Functions
    func applicationDidFinishLaunching(_ notification: Notification) {
        LoggerHelper.setupLogger(log)
        migrateApplicationVersion()
        initializeUserDefaults()
        addObserverForUserDefaults()
        configureMenuItems()
        clearImageCache()
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
    // swiftlint:disable block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // log.debug("detected observing value changed: key[\(keyPath)]")
        guard let keyPath = keyPath, let change = change else { return }

        switch (keyPath, change[.newKey]) {
        case (Parameters.browserInUse, _):
            // log.debug("browserInUse -> \(changed)")
            break

        case (Parameters.commentSpeechVolume, let changed as Int):
            mainWindowControllers.forEach { $0.setVoiceVolume(changed) }

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

        default:
            break
        }
    }
    // swiftlint:enable block_based_kvo
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
            Parameters.enableMuteUserIds: true,
            Parameters.enableMuteWords: true,
            Parameters.alwaysOnTop: false,
            Parameters.commentAnonymously: true]
        UserDefaults.standard.register(defaults: defaults)
    }

    func addObserverForUserDefaults() {
        let keyPaths = [
            // general
            Parameters.browserInUse,
            Parameters.commentSpeechVolume,
            // mute
            Parameters.enableMuteUserIds, Parameters.muteUserIds,
            Parameters.enableMuteWords, Parameters.muteWords,
            // misc
            Parameters.fontSize, Parameters.alwaysOnTop
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

    func clearImageCache() {
        KingfisherManager.shared.cache.clearCache {
            log.debug("Disk cache for images has been cleared.")
        }
    }
}

// MARK: Multi-Window Management
extension AppDelegate {
    var activeMainWindowController: MainWindowController? {
        mainWindowControllers.filter { $0.window?.isKeyWindow == true }.first
    }
}

extension AppDelegate: MainWindowControllerDelegate {
    func mainWindowControllerRequestNewTab(_ mainWindowController: MainWindowController) {
        openNewTab()
    }

    func mainWindowControllerWillClose(_ mainWindowController: MainWindowController) {
        mainWindowControllers.removeAll { $0 == mainWindowController }
        log.debug(mainWindowControllers)
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

    func openNewTab() {
        let wc = MainWindowController.make(delegate: self)
        guard let activeWindow = activeMainWindowController?.window,
              let newWindow = wc.window else { return }
        activeWindow.addTabbedWindow(newWindow, ordered: .above)
        activeWindow.selectNextTab(self)
        mainWindowControllers.append(wc)
        log.debug(mainWindowControllers)
    }

    func closeWindow() {
        guard let window = NSApplication.shared.keyWindow else { return }
        window.close()
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
}

// MARK: Debug Methods
private extension AppDelegate {
    func debugPrintToken() {
        log.debug("accessToken: " + (AuthManager.shared.currentToken?.accessToken ?? "-"))
        log.debug("expireIn: " + String((AuthManager.shared.currentToken?.expiresIn ?? 0)))
        log.debug("refreshToken: " + (AuthManager.shared.currentToken?.refreshToken ?? "-"))
    }
}
