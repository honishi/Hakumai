//
//  AppDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let log = XCGLogger.defaultInstance()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        self.initializeLog()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
    
    // MARK: initializer
    func initializeLog() {
        log.setup(logLevel: .Debug, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil)
    }
    
    // MARK: - Menu Handlers
    @IBAction func openUrl(sender: AnyObject) {
        MainViewController.instance()?.focusLiveTextField()
    }
}

