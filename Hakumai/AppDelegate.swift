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
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - NSApplicationDelegate Functions
    func applicationDidFinishLaunching(_ notification: Notification) {
        Helper.setupLogger(logger)
        migrateApplicationVersion()
        initializeUserDefaults()
        addObserverForUserDefaults()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: Application Initialize Utility
    private func migrateApplicationVersion() {
        let defaults = UserDefaults.standard
        
        let lastVersion = defaults.string(forKey: Parameters.LastLaunchedApplicationVersion)
        let currentVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        logger.info("last launched app version:[\(lastVersion ?? "")] current app version:[\(currentVersion ?? "")]")

        if let lastVersion = lastVersion {
            let lastVersionNumber = Int(lastVersion)!
            let currentVersionNumber = Int(currentVersion!)!

            if lastVersionNumber < currentVersionNumber {
                // do some app version migration here
                logger.info("detected app version up from:[\(lastVersionNumber)] to:[\(currentVersionNumber)]")

                // version migration sample
                /*
                 if lastVersionNumber < 3 {
                 defaults.removeObjectForKey(Parameters.MuteUserIds)
                 defaults.removeObjectForKey(Parameters.MuteWords)
                 defaults.synchronize()
                 }
                 */
            }
        } else {
            logger.info("detected app first launch, no need to migrate application version")
        }
        
        defaults.set(currentVersion!, forKey: Parameters.LastLaunchedApplicationVersion)
        defaults.synchronize()
    }
    
    private func initializeUserDefaults() {
        let defaults: [String: Any] = [
            Parameters.SessionManagement: SessionManagementType.chrome.rawValue,
            Parameters.ShowIfseetnoCommands: false,
            Parameters.FontSize: kDefaultFontSize,
            Parameters.EnableCommentSpeech: false,
            Parameters.EnableMuteUserIds: false,
            Parameters.EnableMuteWords: false,
            Parameters.AlwaysOnTop: false,
            Parameters.CommentAnonymously: true]

        UserDefaults.standard.register(defaults: defaults)
    }
    
    private func addObserverForUserDefaults() {
        let defaults = UserDefaults.standard
        
        // general
        defaults.addObserver(self, forKeyPath: Parameters.SessionManagement, options: [.initial, .new], context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.ShowIfseetnoCommands, options: [.initial, .new], context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.EnableCommentSpeech, options: [.initial, .new], context: nil)
        
        // mute
        defaults.addObserver(self, forKeyPath: Parameters.EnableMuteUserIds, options: [.initial, .new], context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.MuteUserIds, options: [.initial, .new], context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.EnableMuteWords, options: [.initial, .new], context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.MuteWords, options: [.initial, .new], context: nil)
        
        // misc
        defaults.addObserver(self, forKeyPath: Parameters.FontSize, options: [.initial, .new], context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.AlwaysOnTop, options: [.initial, .new], context: nil)
    }

    // MARK: - Internal Functions
    // MARK: KVO Functions
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // logger.debug("detected observing value changed: key[\(keyPath)]")
        guard let keyPath = keyPath, let change = change else {
            return
        }

        switch keyPath {
        case Parameters.SessionManagement:
            NicoUtility.shared.reserveToClearUserSessionCookie()
            
        case Parameters.ShowIfseetnoCommands:
            if let changed = change[.newKey] as? Bool {
                MainViewController.shared.changeShowHbIfseetnoCommands(changed)
            }
            
        case Parameters.EnableCommentSpeech:
            if let changed = change[.newKey] as? Bool {
                MainViewController.shared.changeEnableCommentSpeech(changed)
            }
            
        case Parameters.EnableMuteUserIds:
            if let changed = change[.newKey] as? Bool {
                MainViewController.shared.changeEnableMuteUserIds(changed)
            }
            
        case Parameters.MuteUserIds:
            if let changed = change[.newKey] as? [[String: String]] {
                MainViewController.shared.changeMuteUserIds(changed)
            }
            
        case Parameters.EnableMuteWords:
            if let changed = change[.newKey] as? Bool {
                MainViewController.shared.changeEnableMuteWords(changed)
            }
            
        case Parameters.MuteWords:
            if let changed = change[.newKey] as? [[String: String]] {
                MainViewController.shared.changeMuteWords(changed)
            }

        case Parameters.FontSize:
            if let changed = change[.newKey] as? Float {
                MainViewController.shared.changeFontSize(CGFloat(changed))
            }
            
        case Parameters.AlwaysOnTop:
            if let newValue = change[.newKey] as? Bool {
                makeWindowAlwaysOnTop(newValue)
            }
            
        default:
            break
        }
    }

    // MARK: Menu Handlers
    @IBAction func openPreferences(_ sender: AnyObject) {
        PreferenceWindowController.shared.showWindow(self)
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
    
    // MARK: Misc
    private func makeWindowAlwaysOnTop(_ alwaysOnTop: Bool) {
        let window = NSApplication.shared.windows[0] 
        window.alwaysOnTop = alwaysOnTop
        
        logger.debug("changed always on top: \(alwaysOnTop)")
    }
    
    private func incrementFontSize(_ increment: Float) {
        setFontSize(UserDefaults.standard.float(forKey: Parameters.FontSize) + increment)
    }
    
    private func setFontSize(_ fontSize: Float) {
        guard kMinimumFontSize...kMaximumFontSize ~= fontSize else {
            return
        }
        
        UserDefaults.standard.set(fontSize, forKey: Parameters.FontSize)
        UserDefaults.standard.synchronize()
    }
}

