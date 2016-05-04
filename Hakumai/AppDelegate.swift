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
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        Helper.setupLogger(logger)
        migrateApplicationVersion()
        initializeUserDefaults()
        addObserverForUserDefaults()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: Application Initialize Utility
    func migrateApplicationVersion() {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        let lastVersion = defaults.stringForKey(Parameters.LastLaunchedApplicationVersion)
        let currentVersion = (NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as? String)
        logger.info("last launched app version:[\(lastVersion)] current app version:[\(currentVersion)]")

        if lastVersion == nil {
            logger.info("detected app first launch, no need to migrate application version")
        }
        else {
            let lastVersionNumber = Int(lastVersion!)!
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
        }
        
        defaults.setObject(currentVersion!, forKey: Parameters.LastLaunchedApplicationVersion)
        defaults.synchronize()
    }
    
    func initializeUserDefaults() {
        let defaults: [String: AnyObject] = [
            Parameters.SessionManagement: SessionManagementType.Chrome.rawValue,
            Parameters.ShowIfseetnoCommands: false,
            Parameters.FontSize: kDefaultFontSize,
            Parameters.EnableCommentSpeech: false,
            Parameters.EnableMuteUserIds: false,
            Parameters.EnableMuteWords: false,
            Parameters.AlwaysOnTop: false,
            Parameters.CommentAnonymously: true]

        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
    }
    
    func addObserverForUserDefaults() {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        // general
        defaults.addObserver(self, forKeyPath: Parameters.SessionManagement, options: ([.Initial, .New]), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.ShowIfseetnoCommands, options: ([.Initial, .New]), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.EnableCommentSpeech, options: ([.Initial, .New]), context: nil)
        
        // mute
        defaults.addObserver(self, forKeyPath: Parameters.EnableMuteUserIds, options: ([.Initial, .New]), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.MuteUserIds, options: ([.Initial, .New]), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.EnableMuteWords, options: ([.Initial, .New]), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.MuteWords, options: ([.Initial, .New]), context: nil)
        
        // misc
        defaults.addObserver(self, forKeyPath: Parameters.FontSize, options: ([.Initial, .New]), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.AlwaysOnTop, options: ([.Initial, .New]), context: nil)
    }

    // MARK: - Internal Functions
    // MARK: KVO Functions
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        // logger.debug("detected observing value changed: key[\(keyPath)]")
        guard let keyPath = keyPath, let change = change else {
            return
        }

        switch keyPath {
        case Parameters.SessionManagement:
            NicoUtility.sharedInstance.reserveToClearUserSessionCookie()
            
        case Parameters.ShowIfseetnoCommands:
            if let changed = change["new"] as? Bool {
                MainViewController.sharedInstance.changeShowHbIfseetnoCommands(changed)
            }
            
        case Parameters.EnableCommentSpeech:
            if let changed = change["new"] as? Bool {
                MainViewController.sharedInstance.changeEnableCommentSpeech(changed)
            }
            
        case Parameters.EnableMuteUserIds:
            if let changed = change["new"] as? Bool {
                MainViewController.sharedInstance.changeEnableMuteUserIds(changed)
            }
            
        case Parameters.MuteUserIds:
            if let changed = change["new"] as? [[String: String]] {
                MainViewController.sharedInstance.changeMuteUserIds(changed)
            }
            
        case Parameters.EnableMuteWords:
            if let changed = change["new"] as? Bool {
                MainViewController.sharedInstance.changeEnableMuteWords(changed)
            }
            
        case Parameters.MuteWords:
            if let changed = change["new"] as? [[String: String]] {
                MainViewController.sharedInstance.changeMuteWords(changed)
            }

        case Parameters.FontSize:
            if let changed = change["new"] as? Float {
                MainViewController.sharedInstance.changeFontSize(CGFloat(changed))
            }
            
        case Parameters.AlwaysOnTop:
            if let newValue = change["new"] as? Bool {
                makeWindowAlwaysOnTop(newValue)
            }
            
        default:
            break
        }
    }

    // MARK: Menu Handlers
    @IBAction func openPreferences(sender: AnyObject) {
        PreferenceWindowController.sharedInstance.showWindow(self)
    }
    
    @IBAction func openUrl(sender: AnyObject) {
        MainViewController.sharedInstance.focusLiveTextField()
    }
    
    @IBAction func grabUrlFromChrome(sender: AnyObject) {
        MainViewController.sharedInstance.grabUrlFromBrowser(self)
    }

    @IBAction func newComment(sender: AnyObject) {
        MainViewController.sharedInstance.focusCommentTextField()
    }
    
    @IBAction func zoomDefault(sender: AnyObject) {
        setFontSize(kDefaultFontSize)
    }
    
    @IBAction func zoomIn(sender: AnyObject) {
        incrementFontSize(1)
    }
    
    @IBAction func zoomOut(sender: AnyObject) {
        incrementFontSize(-1)
    }

    // here no handlers for 'Always On Top' menu item. it should be implemented using KVO.
    // see details at http://stackoverflow.com/a/13613507
    
    // MARK: Misc
    func makeWindowAlwaysOnTop(alwaysOnTop: Bool) {
        let window = NSApplication.sharedApplication().windows[0] 
        window.alwaysOnTop = alwaysOnTop
        
        logger.debug("changed always on top: \(alwaysOnTop)")
    }
    
    private func incrementFontSize(increment: Float) {
        setFontSize(NSUserDefaults.standardUserDefaults().floatForKey(Parameters.FontSize) + increment)
    }
    
    private func setFontSize(fontSize: Float) {
        guard kMinimumFontSize...kMaximumFontSize ~= fontSize else {
            return
        }
        
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setFloat(fontSize, forKey: Parameters.FontSize)
        defaults.synchronize()
    }
}

