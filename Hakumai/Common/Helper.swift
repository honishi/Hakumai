//
//  Helper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2/7/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

private let kEnableColorizedLogger = true
private let kLogColors: [(fg: (Int, Int, Int)?, bg: (Int, Int, Int)?)] = [  // solarized dark
    ((147, 161, 161), nil),             // verbose (light grey)
    ((147, 161, 161), nil),             // debug (dark grey)
    (( 38, 139, 210), nil),             // info (blue)
    ((181, 137,   0), nil),             // warning (orange)
    ((220,  50,  47), nil),             // error (red)
    ((238, 232, 213), (220,  50,  47)), // severe (white on red)
]

class Helper {
    // MARK: - Public Interface
    class func setupLogger(logger: XCGLogger) {
        #if DEBUG
            Helper.colorizeLogger(logger)
            logger.setup(.Debug, showLogLevel: true, showFileNames: true, showThreadName: true, showLineNumbers: true, writeToFile: nil)
        #else
            logger.setup(.None, showLogLevel: false, showFileNames: false, showThreadName: false, showLineNumbers: false, writeToFile: nil)
        #endif
    }
    
    class func setupFileLogger(logger: XCGLogger, fileName: String) {
        #if DEBUG
            Helper.colorizeLogger(logger)
            
            Helper.createApplicationDirectoryIfNotExists()
            let path = Helper.applicationDirectoryPath() + "/" + fileName
            logger.setup(.Verbose, showLogLevel: true, showFileNames: true, showThreadName: true, showLineNumbers: true, writeToFile: path)
            
            if let console = logger.logDestination(XCGLogger.constants.baseConsoleLogDestinationIdentifier) {
                logger.removeLogDestination(console)
            }
        #else
            logger.setup(.None, showLogLevel: false, showFileNames: false, showThreadName: false, showLineNumbers: false, writeToFile: nil)
        #endif
    }
    
    class func createApplicationDirectoryIfNotExists() {
        let path = Helper.applicationDirectoryPath()
        
        guard !NSFileManager.defaultManager().fileExistsAtPath(path) else {
            return
        }
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
            logger.debug("created application directory")
        }
        catch {
            logger.error("failed to create application directory")
        }
    }

    class func applicationDirectoryPath() -> String {
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)[0] 
        
        var bundleIdentifier = ""
        if let bi = NSBundle.mainBundle().infoDictionary?["CFBundleIdentifier"] as? String {
            bundleIdentifier = bi
        }
        
        return appSupportDirectory + "/" + bundleIdentifier
    }
    
    // MARK: - Private Functions
    private class func colorizeLogger(logger: XCGLogger) {
        guard kEnableColorizedLogger else {
            return
        }
        
        // solarized dark colors
        logger.xcodeColors = [
            .Verbose:   XCGLogger.XcodeColor(fg: kLogColors[0].fg, bg: kLogColors[0].bg),
            .Debug:     XCGLogger.XcodeColor(fg: kLogColors[1].fg, bg: kLogColors[1].bg),
            .Info:      XCGLogger.XcodeColor(fg: kLogColors[2].fg, bg: kLogColors[2].bg),
            .Warning:   XCGLogger.XcodeColor(fg: kLogColors[3].fg, bg: kLogColors[3].bg),
            .Error:     XCGLogger.XcodeColor(fg: kLogColors[4].fg, bg: kLogColors[4].bg),
            .Severe:    XCGLogger.XcodeColor(fg: kLogColors[5].fg, bg: kLogColors[5].bg),
        ]

        /*
        logger.verbose("test message.")
        logger.debug("test message.")
        logger.info("test message.")
        logger.warning("test message.")
        logger.error("test message.")
        logger.severe("test message.")
        */
    }
}