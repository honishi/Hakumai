//
//  AppDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import XCGLogger

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    let log = XCGLogger.defaultInstance()
    
    // MARK: - NSApplicationDelegate Functions
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        self.initializeLog()
        self.migrateApplicationVersion()
        self.initializeUserDefaults()
        self.addObserverForUserDefaults()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: Application Initialize Utility
    func initializeLog() {
        log.setup(logLevel: .Debug, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil)
    }
    
    func migrateApplicationVersion() {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        let lastVersion = defaults.stringForKey(Parameters.LastLaunchedApplicationVersion)
        let currentVersion = (NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as? String)
        log.info("last launched app version:[\(lastVersion)] current app version:[\(currentVersion)]")

        if lastVersion == nil {
            log.info("detected app first launch, no need to migrate application version")
        }
        else {
            let lastVersionNumber = lastVersion!.toInt()!
            let currentVersionNumber = currentVersion!.toInt()!
            
            if lastVersionNumber < currentVersionNumber {
                // do some app version migration here
                log.info("detected app version up from:[\(lastVersionNumber)] to:[\(currentVersionNumber)]")
                
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
            Parameters.EnableMuteUserIds: false,
            Parameters.EnableMuteWords: false,
            Parameters.AlwaysOnTop: false,
            Parameters.CommentAnonymously: true]

        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
    }
    
    func addObserverForUserDefaults() {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        // general
        defaults.addObserver(self, forKeyPath: Parameters.SessionManagement, options: (.Initial | .New), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.ShowIfseetnoCommands, options: (.Initial | .New), context: nil)
        
        // mute
        defaults.addObserver(self, forKeyPath: Parameters.EnableMuteUserIds, options: (.Initial | .New), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.MuteUserIds, options: (.Initial | .New), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.EnableMuteWords, options: (.Initial | .New), context: nil)
        defaults.addObserver(self, forKeyPath: Parameters.MuteWords, options: (.Initial | .New), context: nil)
        
        // misc
        defaults.addObserver(self, forKeyPath: Parameters.AlwaysOnTop, options: (.Initial | .New), context: nil)
    }

    // MARK: - Internal Functions
    // MARK: KVO Functions
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        // log.debug("detected observing value changed: key[\(keyPath)]")
        
        switch keyPath {
        case Parameters.SessionManagement:
            NicoUtility.sharedInstance.reserveToClearUserSessionCookie()
            
        case Parameters.ShowIfseetnoCommands:
            if let changed = change["new"] as? Bool {
                MainViewController.sharedInstance.changeShowHbIfseetnoCommands(changed)
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

        case Parameters.AlwaysOnTop:
            if let newValue = change["new"] as? Bool {
                // log.debug("\(newValue)")
                self.makeWindowAlwaysOnTop(newValue)
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
    
    // here no handlers for 'Always On Top' menu item. it should be implemented using KVO.
    // see details at http://stackoverflow.com/a/13613507
    
    // MARK: Misc
    func makeWindowAlwaysOnTop(alwaysOnTop: Bool) {
        let window = NSApplication.sharedApplication().windows[0] as NSWindow
        window.alwaysOnTop = alwaysOnTop
        
        log.debug("changed always on top: \(alwaysOnTop)")
    }
}

