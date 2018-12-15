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
    ((181, 137, 0), nil),             // warning (orange)
    ((220, 50, 47), nil),             // error (red)
    ((238, 232, 213), (220, 50, 47)) // severe (white on red)
]

final class Helper {
    // MARK: - Public Interface
    static func setupLogger(_ logger: XCGLogger) {
        #if DEBUG
        Helper.colorizeLogger(logger)
        logger.setup(level: .debug, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil)
        #else
        logger.setup(level: .none, showThreadName: false, showLevel: false, showFileNames: false, showLineNumbers: false, writeToFile: nil)
        #endif
    }

    static func setupFileLogger(_ logger: XCGLogger, fileName: String) {
        #if DEBUG
        Helper.colorizeLogger(logger)

        Helper.createApplicationDirectoryIfNotExists()
        let path = Helper.applicationDirectoryPath() + "/" + fileName
        logger.setup(level: .verbose, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: path)

        if let console = logger.destination(withIdentifier: XCGLogger.Constants.baseConsoleDestinationIdentifier) {
            logger.remove(destination: console)
        }
        #else
        logger.setup(level: .none, showThreadName: false, showLevel: false, showFileNames: false, showLineNumbers: false, writeToFile: nil)
        #endif
    }

    static func createApplicationDirectoryIfNotExists() {
        let path = Helper.applicationDirectoryPath()

        guard !FileManager.default.fileExists(atPath: path) else {
            return
        }

        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            logger.debug("created application directory")
        } catch {
            logger.error("failed to create application directory")
        }
    }

    static func applicationDirectoryPath() -> String {
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]

        var bundleIdentifier = ""
        if let bi = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String {
            bundleIdentifier = bi
        }

        return appSupportDirectory + "/" + bundleIdentifier
    }

    // MARK: - Private Functions
    private static func colorizeLogger(_ logger: XCGLogger) {
        guard kEnableColorizedLogger else {
            return
        }

        // solarized dark colors
        // XXX: turn the colors off, temporarily
        /*
         logger.xcodeColors = [
         .verbose:   XCGLogger.XcodeColor(fg: kLogColors[0].fg, bg: kLogColors[0].bg),
         .debug:     XCGLogger.XcodeColor(fg: kLogColors[1].fg, bg: kLogColors[1].bg),
         .info:      XCGLogger.XcodeColor(fg: kLogColors[2].fg, bg: kLogColors[2].bg),
         .warning:   XCGLogger.XcodeColor(fg: kLogColors[3].fg, bg: kLogColors[3].bg),
         .error:     XCGLogger.XcodeColor(fg: kLogColors[4].fg, bg: kLogColors[4].bg),
         .severe:    XCGLogger.XcodeColor(fg: kLogColors[5].fg, bg: kLogColors[5].bg),
         ]
         */

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
