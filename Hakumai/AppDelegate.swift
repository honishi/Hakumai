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
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
    
    // MARK: initializer
    func initializeLog() {
        log.setup(logLevel: .Debug, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil)
    }
    
    func initializeUserDefaults() {
        let defaults: [String: AnyObject] = [
            Parameters.ShowIfseetnoCommands: false]

        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
    }
    
    // MARK: - Menu Handlers
    
    @IBAction func openPreferences(sender: AnyObject) {
        PreferenceWindowController.sharedInstance.showWindow(self)
    }
    
    @IBAction func openUrl(sender: AnyObject) {
        MainViewController.sharedInstance.focusLiveTextField()
    }
    
    @IBAction func newComment(sender: AnyObject) {
        MainViewController.sharedInstance.focusCommentTextField()
    }
}

