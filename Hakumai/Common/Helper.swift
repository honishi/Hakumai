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

final class Helper {
    // MARK: - Public Interface
    static func setupLogger(_ logger: XCGLogger) {
        #if DEBUG
        Helper.colorizeLogger(logger)
        logger.setup(
            level: .debug,
            showThreadName: true,
            showLevel: true,
            showFileNames: true,
            showLineNumbers: true,
            writeToFile: nil)
        #else
        logger.setup(
            level: .none,
            showThreadName: false,
            showLevel: false,
            showFileNames: false,
            showLineNumbers: false,
            writeToFile: nil)
        #endif
    }

    static func setupFileLogger(_ logger: XCGLogger, fileName: String) {
        #if DEBUG
        Helper.colorizeLogger(logger)

        Helper.createApplicationDirectoryIfNotExists()
        let path = Helper.applicationDirectoryPath() + "/" + fileName
        logger.setup(
            level: .verbose,
            showThreadName: true,
            showLevel: true,
            showFileNames: true,
            showLineNumbers: true,
            writeToFile: path)

        if let console = logger.destination(withIdentifier: XCGLogger.Constants.baseConsoleDestinationIdentifier) {
            logger.remove(destination: console)
        }
        #else
        logger.setup(
            level: .none,
            showThreadName: false,
            showLevel: false,
            showFileNames: false,
            showLineNumbers: false,
            writeToFile: nil)
        #endif
    }

    static func createApplicationDirectoryIfNotExists() {
        let path = Helper.applicationDirectoryPath()
        guard !FileManager.default.fileExists(atPath: path) else { return }
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            log.debug("created application directory")
        } catch {
            log.error("failed to create application directory")
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
        guard kEnableColorizedLogger else { return }
        logger.levelDescriptions = [
            .verbose: "🟢:\(XCGLogger.Level.verbose.description)",
            .debug: "🔵:\(XCGLogger.Level.debug.description)",
            .info: "⚪️:\(XCGLogger.Level.info.description)",
            .notice: "⚪️:\(XCGLogger.Level.notice.description)",
            .warning: "🟠:\(XCGLogger.Level.warning.description)",
            .error: "🔴:\(XCGLogger.Level.error.description)",
            .severe: "🟣:\(XCGLogger.Level.severe.description)", // aka critical
            .alert: "🔴:\(XCGLogger.Level.alert.description)",
            .emergency: "🟣:\(XCGLogger.Level.emergency.description)"
            // .none: "\(XCGLogger.Level.none.description)"
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
