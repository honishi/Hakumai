//
//  ApiHelper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2/7/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// logger for class methods
private let log = XCGLogger.defaultInstance()

class ApiHelper {
    // MARK: - Public Interface
    class func setupFileLog(fileLog: XCGLogger, fileName: String) {
        #if DEBUG
            ApiHelper.createApplicationDirectoryIfNotExists()
            let fileLogPath = ApiHelper.applicationDirectoryPath() + "/" + fileName
            fileLog.setup(logLevel: .Verbose, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: fileLogPath)
            
            if let console = fileLog.logDestination(XCGLogger.constants.baseConsoleLogDestinationIdentifier) {
                fileLog.removeLogDestination(console)
            }
        #else
            fileLog.setup(logLevel: .None, showLogLevel: false, showFileNames: false, showLineNumbers: false, writeToFile: nil)
        #endif
    }
    
    class func createApplicationDirectoryIfNotExists() {
        let directoryExists = NSFileManager.defaultManager().fileExistsAtPath(ApiHelper.applicationDirectoryPath())
        
        if !directoryExists {
            let created = NSFileManager.defaultManager().createDirectoryAtPath(ApiHelper.applicationDirectoryPath(), withIntermediateDirectories: false, attributes: nil, error: nil)
            
            if created {
                log.debug("created application directory")
            }
            else {
                log.error("failed to create application directory")
            }
        }
    }

    class func applicationDirectoryPath() -> String {
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)[0] as! String
        
        var bundleIdentifier = ""
        if let bi = NSBundle.mainBundle().infoDictionary?["CFBundleIdentifier"] as? String {
            bundleIdentifier = bi
        }
        
        return appSupportDirectory + "/" + bundleIdentifier
    }
}