//
//  AppDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - NSApplicationDelegate Functions
    func applicationDidFinishLaunching(_ notification: Notification) {
        Helper.setupLogger(log)
        migrateApplicationVersion()
        initializeUserDefaults()
        addObserverForUserDefaults()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: Menu Handlers
extension AppDelegate {
    @IBAction func openPreferences(_ sender: AnyObject) {
        PreferenceWindowController.shared?.showWindow(self)
    }

    @IBAction func openUrl(_ sender: AnyObject) {
        MainViewController.shared.focusLiveTextField()
    }

    @IBAction func grabUrlFromChrome(_ sender: AnyObject) {
        MainViewController.shared.grabUrlFromBrowser(self)
    }

    @IBAction func newComment(_ sender: AnyObject) {
        MainViewController.shared.focusCommentTextField()
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
    // swiftlint:disable cyclomatic_complexity block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // log.debug("detected observing value changed: key[\(keyPath)]")
        guard let keyPath = keyPath, let change = change else { return }

        switch (keyPath, change[.newKey]) {
        case (Parameters.sessionManagement, _):
            NicoUtility.shared.reserveToClearUserSessionCookie()

        case (Parameters.showIfseetnoCommands, let changed as Bool):
            MainViewController.shared.changeShowHbIfseetnoCommands(changed)

        case (Parameters.enableCommentSpeech, let changed as Bool):
            MainViewController.shared.changeEnableCommentSpeech(changed)

        case (Parameters.enableMuteUserIds, let changed as Bool):
            MainViewController.shared.changeEnableMuteUserIds(changed)

        case (Parameters.muteUserIds, let changed as [[String: String]]):
            MainViewController.shared.changeMuteUserIds(changed)

        case (Parameters.enableMuteWords, let changed as Bool):
            MainViewController.shared.changeEnableMuteWords(changed)

        case (Parameters.muteWords, let changed as [[String: String]]):
            MainViewController.shared.changeMuteWords(changed)

        case (Parameters.fontSize, let changed as Float):
            MainViewController.shared.changeFontSize(CGFloat(changed))

        case (Parameters.alwaysOnTop, let newValue as Bool):
            makeWindowAlwaysOnTop(newValue)

        default:
            break
        }
    }
    // swiftlint:enable cyclomatic_complexity block_based_kvo
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
            Parameters.sessionManagement: SessionManagementType.chrome.rawValue,
            Parameters.showIfseetnoCommands: false,
            Parameters.fontSize: kDefaultFontSize,
            Parameters.enableCommentSpeech: false,
            Parameters.enableMuteUserIds: false,
            Parameters.enableMuteWords: false,
            Parameters.alwaysOnTop: false,
            Parameters.commentAnonymously: true]
        UserDefaults.standard.register(defaults: defaults)
    }

    func addObserverForUserDefaults() {
        let keyPaths = [
            // general
            Parameters.sessionManagement, Parameters.showIfseetnoCommands,
            Parameters.enableCommentSpeech,
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
}

// MARK: Misc
private extension AppDelegate {
    func makeWindowAlwaysOnTop(_ alwaysOnTop: Bool) {
        let window = NSApplication.shared.windows[0]
        window.alwaysOnTop = alwaysOnTop
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
