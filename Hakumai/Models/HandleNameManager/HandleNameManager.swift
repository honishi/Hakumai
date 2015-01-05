//
//  HandleNameManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

private let kHandleNamesFileName = "HandleNames.plist"
private let kHandleNamesDictionaryKeyHandleName = "HandleName"
private let kHandleNamesDictionaryKeyUpdateDate = "UpdateDate"

private let kHandleNameObsoleteThreshold = NSTimeInterval(60 * 60 * 24 * 7) // = 1 week

// comment like "@5" (="あと5分")
private let kRegexpRemainingTime = "[@＠][0-9０-９]{1,2}$"
// mail address regular expression based on http://qiita.com/sakuro/items/1eaa307609ceaaf51123
private let kRegexpMailAddress = "[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*"
private let kRegexpHandleName = ".*[@＠]\\s*(\\S{2,})\\s*"

// handle name manager
class HandleNameManager {
    // MARK: - Properties
    
    // handle name dictionary that have the following structrue:
    // @{userId:
    //     @{kHandleNamesDictionaryKeyHandleName: handleName,
    //       kHandleNamesDictionaryKeyUpdateDate: updateDate}
    // }
    // implementing the dictionary using NSMutableDictionary instead of swift Dictionary.
    // cause we use NSMutableDictionary's method like writeToFile() to serialize data.
    private var handleNames = NSMutableDictionary()
    
    private let log = XCGLogger.defaultInstance()
    
    // MARK: - Object Lifecycle
    class var sharedManager : HandleNameManager {
        struct Static {
            static let instance = HandleNameManager()
        }
        return Static.instance
    }
    
    init() {
        objc_sync_enter(self)
        self.createApplicationDirectoryIfNotExists()
        self.readHandleNamesFromDisk()
        self.cleanObsoleteHandleNames()
        objc_sync_exit(self)
    }

    // MARK: - Public Functions
    func extractAndUpdateHandleNameWithChat(chat: Chat) {
        if chat.userId == nil || chat.comment == nil {
            return
        }
        
        if let handleName = self.extractHandleNameFromComment(chat.comment!) {
            self.updateHandleNameWithChat(chat, handleName: handleName)
        }
    }
    
    func updateHandleNameWithChat(chat: Chat, handleName: String) {
        if chat.userId == nil {
            return
        }
        
        let handleNameValue = NSMutableDictionary()
        handleNameValue[kHandleNamesDictionaryKeyHandleName] = handleName
        handleNameValue[kHandleNamesDictionaryKeyUpdateDate] = NSDate()

        objc_sync_enter(self)
        self.handleNames[chat.userId!] = handleNameValue
        self.writeHandleNamesToDisk()
        objc_sync_exit(self)
    }
    
    func removeHandleNameWithChat(chat: Chat) {
        if chat.userId == nil {
            return
        }
        
        objc_sync_enter(self)
        self.handleNames.removeObjectForKey(chat.userId!)
        self.writeHandleNamesToDisk()
        objc_sync_exit(self)
    }
    
    func handleNameForChat(chat: Chat) -> String? {
        if chat.userId == nil {
            return nil
        }
        
        var handleName: String?
        
        objc_sync_enter(self)
        if let handleNameValue = self.handleNames[chat.userId!] as? NSDictionary {
            if let cached = handleNameValue[kHandleNamesDictionaryKeyHandleName] as? String {
                handleName = cached
            }
        }
        objc_sync_exit(self)
        
        return handleName
    }
    
    // MARK: - Internal Functions
    func extractHandleNameFromComment(comment: String) -> String? {
        if comment.hasRegexpPattern(kRegexpRemainingTime) {
            return nil
        }
        
        if comment.hasRegexpPattern(kRegexpMailAddress) {
            return nil
        }
        
        let handleName = comment.extractRegexpPattern(kRegexpHandleName)
        return handleName
    }
    
    // MARK: Serialize Functions
    func writeHandleNamesToDisk() {
        self.handleNames.writeToFile(HandleNameManager.fullPathForHandleNamesFile(), atomically: true)
    }
    
    func readHandleNamesFromDisk() {
        log.debug("handle names file target:[\(HandleNameManager.fullPathForHandleNamesFile())]")
        let nsHandleNames = NSMutableDictionary(contentsOfFile: HandleNameManager.fullPathForHandleNamesFile())
        
        if nsHandleNames != nil {
            self.handleNames = nsHandleNames!
            log.debug("found and read handle names on disk")
        }
        else {
            log.debug("not found handle names on disk")
        }
    }
    
    func cleanObsoleteHandleNames() {
        var userIdsTobeDeleted = [AnyObject]()
        
        for (userId, handleNameValue) in self.handleNames {
            if Chat.isRawUserId((userId as String)) {
                continue
            }
            
            if let updateDate = handleNameValue[kHandleNamesDictionaryKeyUpdateDate] as? NSDate {
                let obsoleted = (updateDate.timeIntervalSinceNow < -kHandleNameObsoleteThreshold)
                if obsoleted {
                    userIdsTobeDeleted.append(userId)
                }
            }
        }
        
        log.debug("userIdsToBeDeleted:[\(userIdsTobeDeleted)]")
        self.handleNames.removeObjectsForKeys(userIdsTobeDeleted)
        self.writeHandleNamesToDisk()
    }
    
    func createApplicationDirectoryIfNotExists() {
        let directoryExists = NSFileManager.defaultManager().fileExistsAtPath(HandleNameManager.applicationDirectoryPath())
        
        if !directoryExists {
            let created = NSFileManager.defaultManager().createDirectoryAtPath(HandleNameManager.applicationDirectoryPath(), withIntermediateDirectories: false, attributes: nil, error: nil)
            
            if created {
                log.debug("created application directory")
            }
        }
    }
    
    // MARK: File Path
    class func applicationDirectoryPath() -> String {
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)[0] as String
        
        var bundleIdentifier = ""
        if let bi = NSBundle.mainBundle().infoDictionary?["CFBundleIdentifier"] as? String {
            bundleIdentifier = bi
        }
        
        return appSupportDirectory + "/" + bundleIdentifier
    }
    
    class func fullPathForHandleNamesFile() -> String {
        return HandleNameManager.applicationDirectoryPath() + "/" + kHandleNamesFileName
    }
}
