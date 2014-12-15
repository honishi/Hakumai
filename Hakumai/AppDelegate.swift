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
        self.initializeUserDefaults()
        self.addObserverForUserDefaults()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
    
    // MARK: initializer
    func initializeLog() {
        log.setup(logLevel: .Debug, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil)
    }
    
    func initializeUserDefaults() {
        let defaults: [String: AnyObject] = [
            Parameters.AlwaysOnTop: false,
            Parameters.ShowIfseetnoCommands: false,
            Parameters.CommentAnonymously: true]

        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
    }
    
    func addObserverForUserDefaults() {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        defaults.addObserver(self, forKeyPath: Parameters.AlwaysOnTop, options: (.Initial | .New), context: nil)
    }

    // MARK: - KVO Functions
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        // log.debug("detected observing value changed: key[\(keyPath)]")
        
        if keyPath == Parameters.AlwaysOnTop {
            if let newValue = change["new"] as? Bool {
                // log.debug("\(newValue)")
                self.makeWindowAlwaysOnTop(newValue)
            }
        }
    }

    // MARK: - Internal Functions
    // MARK: Menu Handlers
    @IBAction func openPreferences(sender: AnyObject) {
        PreferenceWindowController.sharedInstance.showWindow(self)
    }
    
    @IBAction func openUrl(sender: AnyObject) {
        MainViewController.sharedInstance.focusLiveTextField()
    }
    
    @IBAction func newComment(sender: AnyObject) {
        MainViewController.sharedInstance.focusCommentTextField()
    }
    
    // here no handlers for 'Always On Top' menu item. it should be implemented using KVO.
    // see detail at http://stackoverflow.com/a/13613507
    
    // MARK: Misc
    func makeWindowAlwaysOnTop(alwaysOnTop: Bool) {
        let window = NSApplication.sharedApplication().windows[0] as NSWindow
        window.alwaysOnTop = alwaysOnTop
        
        log.debug("changed always on top: \(alwaysOnTop)")
    }
}

