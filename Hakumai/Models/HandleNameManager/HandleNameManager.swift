//
//  HandleNameManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import FMDB

private let kHandleNamesDatabase = "HandleNames"
private let kHandleNamesTable = "handle_names"
private let kHandleNameObsoleteThreshold = NSTimeInterval(60 * 60 * 24 * 7) // = 1 week

// comment like "@5" (="あと5分")
private let kRegexpRemainingTime = "[@＠][0-9０-９]{1,2}$"
private let kRegexpHandleName = ".*[@＠]\\s*(\\S{2,})\\s*"

// handle name manager
class HandleNameManager {
    // MARK: - Properties
    static let sharedManager = HandleNameManager()
    
    private var database: FMDatabase!
    private var databaseQueue: FMDatabaseQueue!
    
    // MARK: - Object Lifecycle
    init() {
        objc_sync_enter(self)
        Helper.createApplicationDirectoryIfNotExists()
        database = HandleNameManager.databaseForHandleNames()
        databaseQueue = HandleNameManager.databaseQueueForHandleNames()
        createHandleNamesTableIfNotExists()
        deleteObsoletedHandleNames()
        objc_sync_exit(self)
    }

    // MARK: - Public Functions
    func extractAndUpdateHandleNameWithLive(live: Live, chat: Chat) {
        if chat.userId == nil || chat.comment == nil {
            return
        }
        
        if let handleName = extractHandleNameFromComment(chat.comment!) {
            updateHandleNameWithLive(live, chat: chat, handleName: handleName)
        }
    }
    
    func updateHandleNameWithLive(live: Live, chat: Chat, handleName: String) {
        guard let communityId = live.community.community, let userId = chat.userId else {
            return
        }
        
        let anonymous = !chat.isRawUserId
        insertOrReplaceHandleNameWithCommunityId(communityId, userId: userId, anonymous: anonymous, handleName: handleName)
    }
    
    func removeHandleNameWithLive(live: Live, chat: Chat) {
        guard let communityId = live.community.community, let userId = chat.userId else {
            return
        }

        deleteHandleNameWithCommunityId(communityId, userId: userId)
    }
    
    func handleNameForLive(live: Live, chat: Chat) -> String? {
        guard let communityId = live.community.community, let userId = chat.userId else {
            return nil
        }
        
        return selectHandleNameWithCommunityId(communityId, userId: userId)
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
    
    // MARK: Database Functions
    // for test
    private func dropHandleNamesTableIfExists() {
        guard let database = database else {
            return
        }
        
        let dropTableSql = "drop table if exists " + kHandleNamesTable
        
        objc_sync_enter(self)
        let success = database.executeUpdate(dropTableSql, withArgumentsInArray: nil)
        objc_sync_exit(self)
        
        if !success {
            logger.error("failed to drop table: \(database.lastErrorMessage())")
        }
    }
    
    private func createHandleNamesTableIfNotExists() {
        guard let database = database else {
            return
        }

        // currently not used but reserved columns; color, reserved1, reserved2, reserved3
        let createTableSql = "create table if not exists " + kHandleNamesTable + " " +
            "(community_id text, user_id text, handle_name text, anonymous integer, color text, updated integer, " +
            "reserved1 text, reserved2 text, reserved3 text, " +
            "primary key (community_id, user_id))"
        
        objc_sync_enter(self)
        let success = database.executeUpdate(createTableSql, withArgumentsInArray: nil)
        objc_sync_exit(self)
        
        if !success {
            logger.error("failed to create table: \(database.lastErrorMessage())")
        }
    }
    
    func insertOrReplaceHandleNameWithCommunityId(communityId: String, userId: String, anonymous: Bool, handleName: String) {
        guard databaseQueue != nil else {
            logger.warning("database not ready")
            return
        }
        
        let insertSql = "insert or replace into " + kHandleNamesTable + " " +
            "values (?, ?, ?, ?, null, strftime('%s', 'now'), null, null, null)"

        databaseQueue.inDatabase { database in
            database.executeUpdate(insertSql, withArgumentsInArray: [communityId, userId, handleName, anonymous])
        }
    }

    func selectHandleNameWithCommunityId(communityId: String, userId: String) -> String? {
        guard let database = database else {
            return nil
        }
      
        let selectSql = "select handle_name from " + kHandleNamesTable + " where community_id = ? and user_id = ?"
        var handleName: String?
        
        objc_sync_enter(self)
        let resultSet = database.executeQuery(selectSql, withArgumentsInArray: [communityId, userId])
        while resultSet.next() {
            handleName = resultSet.stringForColumn("handle_name")
            break
        }
        resultSet.close()
        objc_sync_exit(self)
        
        return handleName
    }
    
    private func deleteHandleNameWithCommunityId(communityId: String, userId: String) {
        guard let database = database else {
            return
        }
        
        let deleteSql = "delete from " + kHandleNamesTable + " where community_id = ? and user_id = ?"
        
        objc_sync_enter(self)
        let success = database.executeUpdate(deleteSql, withArgumentsInArray: [communityId, userId])
        objc_sync_exit(self)
        
        if !success {
            logger.error("failed to delete table: \(database.lastErrorMessage())")
        }
    }
    
    private func deleteObsoletedHandleNames() {
        guard let database = database else {
            return
        }
        
        let deleteSql = "delete from " + kHandleNamesTable + " where updated < ? and anonymous = 1"
        let threshold = NSDate().timeIntervalSince1970 - kHandleNameObsoleteThreshold
        
        objc_sync_enter(self)
        let success = database.executeUpdate(deleteSql, withArgumentsInArray: [threshold])
        objc_sync_exit(self)
        
        if !success {
            logger.error("failed to delete table: \(database.lastErrorMessage())")
        }
    }
    
    // MARK: Database Instance Utility
    private class func fullPathForHandleNamesDatabase() -> String {
        return Helper.applicationDirectoryPath() + "/" + kHandleNamesDatabase
    }
    
    private class func databaseForHandleNames() -> FMDatabase? {
        let database = FMDatabase(path: HandleNameManager.fullPathForHandleNamesDatabase())
        
        if !database.open() {
            logger.error("unable to open database")
            return nil
        }
        
        return database
    }
    
    private class func databaseQueueForHandleNames() -> FMDatabaseQueue? {
        return FMDatabaseQueue(path: HandleNameManager.fullPathForHandleNamesDatabase())
    }
}
