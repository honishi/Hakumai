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
private let kHandleNameObsoleteThreshold = TimeInterval(60 * 60 * 24 * 7) // = 1 week

// comment like "@5" (="あと5分")
private let kRegexpRemainingTime = "[@＠][0-9０-９]{1,2}$"
private let kRegexpHandleName = ".*[@＠]\\s*(\\S{2,})\\s*"

// handle name manager
final class HandleNameManager {
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
    func extractAndUpdateHandleName(live: Live, chat: Chat) {
        guard chat.userId != nil, let comment = chat.comment,
            let handleName = extractHandleName(fromComment: comment) else { return }
        updateHandleName(live: live, chat: chat, handleName: handleName)
    }

    func updateHandleName(live: Live, chat: Chat, handleName: String) {
        guard let communityId = live.community.community, let userId = chat.userId else { return }
        let anonymous = !chat.isRawUserId
        insertOrReplaceHandleName(communityId: communityId, userId: userId, anonymous: anonymous, handleName: handleName)
    }

    func removeHandleName(live: Live, chat: Chat) {
        guard let communityId = live.community.community, let userId = chat.userId else { return }
        deleteHandleName(communityId: communityId, userId: userId)
    }

    func handleName(forLive live: Live, chat: Chat) -> String? {
        guard let communityId = live.community.community, let userId = chat.userId else { return nil }
        return selectHandleName(communityId: communityId, userId: userId)
    }

    // MARK: - Internal Functions
    func extractHandleName(fromComment comment: String) -> String? {
        if comment.hasRegexp(pattern: kRegexpRemainingTime) {
            return nil
        }

        if comment.hasRegexp(pattern: kRegexpMailAddress) {
            return nil
        }

        let handleName = comment.extractRegexp(pattern: kRegexpHandleName)
        return handleName
    }

    // MARK: Database Functions
    // for test
    private func dropHandleNamesTableIfExists() {
        guard let database = database else { return }

        let dropTableSql = "drop table if exists " + kHandleNamesTable

        objc_sync_enter(self)
        let success = database.executeUpdate(dropTableSql, withArgumentsIn: nil)
        objc_sync_exit(self)

        if !success {
            logger.error("failed to drop table: \(String(describing: database.lastErrorMessage()))")
        }
    }

    private func createHandleNamesTableIfNotExists() {
        guard let database = database else { return }

        // currently not used but reserved columns; color, reserved1, reserved2, reserved3
        let createTableSql = "create table if not exists " + kHandleNamesTable + " " +
            "(community_id text, user_id text, handle_name text, anonymous integer, color text, updated integer, " +
            "reserved1 text, reserved2 text, reserved3 text, " +
        "primary key (community_id, user_id))"

        objc_sync_enter(self)
        let success = database.executeUpdate(createTableSql, withArgumentsIn: nil)
        objc_sync_exit(self)

        if !success {
            logger.error("failed to create table: \(String(describing: database.lastErrorMessage()))")
        }
    }

    func insertOrReplaceHandleName(communityId: String, userId: String, anonymous: Bool, handleName: String) {
        guard databaseQueue != nil else {
            logger.warning("database not ready")
            return
        }

        let insertSql = "insert or replace into " + kHandleNamesTable + " " +
        "values (?, ?, ?, ?, null, strftime('%s', 'now'), null, null, null)"

        databaseQueue.inDatabase { database in
            database?.executeUpdate(insertSql, withArgumentsIn: [communityId, userId, handleName, anonymous])
        }
    }

    func selectHandleName(communityId: String, userId: String) -> String? {
        guard let database = database else { return nil }

        let selectSql = "select handle_name from " + kHandleNamesTable + " where community_id = ? and user_id = ?"
        var handleName: String?

        objc_sync_enter(self)
        let resultSet = database.executeQuery(selectSql, withArgumentsIn: [communityId, userId])
        while (resultSet?.next())! {
            handleName = resultSet?.string(forColumn: "handle_name")
            break
        }
        resultSet?.close()
        objc_sync_exit(self)

        return handleName
    }

    private func deleteHandleName(communityId: String, userId: String) {
        guard let database = database else { return }

        let deleteSql = "delete from " + kHandleNamesTable + " where community_id = ? and user_id = ?"

        objc_sync_enter(self)
        let success = database.executeUpdate(deleteSql, withArgumentsIn: [communityId, userId])
        objc_sync_exit(self)

        if !success {
            logger.error("failed to delete table: \(String(describing: database.lastErrorMessage()))")
        }
    }

    private func deleteObsoletedHandleNames() {
        guard let database = database else { return }

        let deleteSql = "delete from " + kHandleNamesTable + " where updated < ? and anonymous = 1"
        let threshold = Date().timeIntervalSince1970 - kHandleNameObsoleteThreshold

        objc_sync_enter(self)
        let success = database.executeUpdate(deleteSql, withArgumentsIn: [threshold])
        objc_sync_exit(self)

        if !success {
            logger.error("failed to delete table: \(String(describing: database.lastErrorMessage()))")
        }
    }

    // MARK: Database Instance Utility
    private static func fullPathForHandleNamesDatabase() -> String {
        return Helper.applicationDirectoryPath() + "/" + kHandleNamesDatabase
    }

    private static func databaseForHandleNames() -> FMDatabase? {
        let database = FMDatabase(path: HandleNameManager.fullPathForHandleNamesDatabase())

        if !(database?.open())! {
            logger.error("unable to open database")
            return nil
        }

        return database
    }

    private static func databaseQueueForHandleNames() -> FMDatabaseQueue? {
        return FMDatabaseQueue(path: HandleNameManager.fullPathForHandleNamesDatabase())
    }
}
