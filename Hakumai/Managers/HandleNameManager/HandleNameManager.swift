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
    static let shared = HandleNameManager()

    private var database: FMDatabase!
    private var databaseQueue: FMDatabaseQueue!

    private let handleNameCacher = DatabaseValueCacher<String>()
    private let colorCacher = DatabaseValueCacher<NSColor>()

    // MARK: - Object Lifecycle
    init() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        LoggerHelper.createApplicationDirectoryIfNotExists()
        database = HandleNameManager.databaseForHandleNames()
        databaseQueue = HandleNameManager.databaseQueueForHandleNames()
        createHandleNamesTableIfNotExists()
        deleteObsoleteRows()
    }
}

// MARK: - Public Functions
extension HandleNameManager {
    func extractAndUpdateHandleName(from comment: String, for userId: String, in communityId: String) {
        guard let handleName = extractHandleName(from: comment) else { return }
        setHandleName(name: handleName, for: userId, in: communityId)
    }

    func setHandleName(name: String, for userId: String, in communityId: String) {
        upsert(handleName: name, for: userId, in: communityId)
        handleNameCacher.update(value: name, for: userId, in: communityId)
    }

    func removeHandleName(for userId: String, in communityId: String) {
        updateHandleNameToNull(for: userId, in: communityId)
        deleteRowIfHasNoData(for: userId, in: communityId)
        handleNameCacher.updateValueAsNil(for: userId, in: communityId)
    }

    func handleName(for userId: String, in communityId: String) -> String? {
        let cached = handleNameCacher.cachedValue(for: userId, in: communityId)
        switch cached {
        case .cached(let handleName):
            // log.debug("handleName: cached: \(handleName ?? "nil")")
            return handleName
        case .notCached:
            // log.debug("handleName: not cached")
            break
        }
        let queried = selectHandleName(for: userId, in: communityId)
        handleNameCacher.update(value: queried, for: userId, in: communityId)
        // log.debug("handleName: update cache: \(queried ?? "nil")")
        return queried
    }

    func setColor(_ color: NSColor, for userId: String, in communityId: String) {
        upsert(color: color, for: userId, in: communityId)
        colorCacher.update(value: color, for: userId, in: communityId)
    }

    func removeColor(for userId: String, in communityId: String) {
        updateColorToNull(for: userId, in: communityId)
        deleteRowIfHasNoData(for: userId, in: communityId)
        colorCacher.updateValueAsNil(for: userId, in: communityId)
    }

    func color(for userId: String, in communityId: String) -> NSColor? {
        let cached = colorCacher.cachedValue(for: userId, in: communityId)
        switch cached {
        case .cached(let color):
            // log.debug("color: cached: \(color?.description ?? "nil")")
            return color
        case .notCached:
            // log.debug("color: not cached")
            break
        }
        let queried = selectColor(for: userId, in: communityId)
        colorCacher.update(value: queried, for: userId, in: communityId)
        // log.debug("color: update cache: \(queried?.description ?? "nil")")
        return queried
    }
}

// MARK: - Internal Functions
extension HandleNameManager {
    func extractHandleName(from comment: String) -> String? {
        if comment.hasRegexp(pattern: kRegexpRemainingTime) {
            return nil
        }
        if comment.hasRegexp(pattern: kRegexpMailAddress) {
            return nil
        }
        return comment.extractRegexp(pattern: kRegexpHandleName)
    }

    func upsert(handleName: String, for userId: String, in communityId: String) {
        if isRowExisted(for: userId, in: communityId) {
            update(column: "handle_name", value: handleName, for: userId, in: communityId)
        } else {
            insert(handleName: handleName, for: userId, in: communityId)
        }
    }

    func selectHandleName(for userId: String, in communityId: String) -> String? {
        return select(column: "handle_name", for: userId, in: communityId)
    }

    func upsert(color: NSColor, for userId: String, in communityId: String) {
        let colorHex = color.hex
        guard colorHex.isValidHexString else { return }
        if isRowExisted(for: userId, in: communityId) {
            update(column: "color", value: colorHex, for: userId, in: communityId)
        } else {
            insert(colorHex: colorHex, for: userId, in: communityId)
        }
    }

    func selectColor(for userId: String, in communityId: String) -> NSColor? {
        let string = select(column: "color", for: userId, in: communityId)
        guard let _string = string, _string.isValidHexString else { return nil }
        return NSColor(hex: _string)
    }
}

// MARK: DDL Functions
private extension HandleNameManager {
    func dropHandleNamesTableIfExists() {
        let sql = """
            drop table if exists \(kHandleNamesTable)
        """
        executeUpdate(sql, args: [])
    }

    func createHandleNamesTableIfNotExists() {
        let sql = """
            create table if not exists \(kHandleNamesTable)
            (community_id text, user_id text, handle_name text, anonymous integer,
            color text, updated integer,
            reserved1 text, reserved2 text, reserved3 text,
            primary key (community_id, user_id))
        """
        executeUpdate(sql, args: [])
    }
}

// MARK: Select + DML Functions
private extension HandleNameManager {
    func isRowExisted(for userId: String, in communityId: String) -> Bool {
        return select(column: "user_id", for: userId, in: communityId) != nil
    }

    func select(column: String, for userId: String, in communityId: String) -> String? {
        let sql = """
            select \(column) from \(kHandleNamesTable)
            where community_id = ? and user_id = ?
        """
        return executeQuery(sql, args: [communityId, userId], column: column)
    }

    func insert(handleName: String, for userId: String, in communityId: String) {
        let sql = """
            insert into \(kHandleNamesTable)
            values (?, ?, ?, ?, null, strftime('%s', 'now'), null, null, null)
        """
        executeUpdate(sql, args: [communityId, userId, handleName, userId.isAnonymous])
    }

    func insert(colorHex: String, for userId: String, in communityId: String) {
        let sql = """
            insert into \(kHandleNamesTable)
            values (?, ?, null, ?, ?, strftime('%s', 'now'), null, null, null)
        """
        executeUpdate(sql, args: [communityId, userId, userId.isAnonymous, colorHex])
    }

    func update(column: String, value: Any, for userId: String, in communityId: String) {
        let sql = """
            update \(kHandleNamesTable) set \(column) = ?
            where community_id = ? and user_id = ?
        """
        executeUpdate(sql, args: [value, communityId, userId])
    }

    func updateHandleNameToNull(for userId: String, in communityId: String) {
        _updateColumnToNull(column: "handle_name", for: userId, in: communityId)
    }

    func updateColorToNull(for userId: String, in communityId: String) {
        _updateColumnToNull(column: "color", for: userId, in: communityId)
    }

    func _updateColumnToNull(column: String, for userId: String, in communityId: String) {
        let sql = """
            update \(kHandleNamesTable)
            set \(column) = null
            where community_id = ? and user_id = ?
        """
        executeUpdate(sql, args: [communityId, userId])
    }

    func deleteRowIfHasNoData(for userId: String, in communityId: String) {
        let sql = """
            delete from \(kHandleNamesTable)
            where community_id = ? and user_id = ? and
            handle_name is null and color is null
        """
        executeUpdate(sql, args: [communityId, userId])
    }

    func deleteObsoleteRows() {
        let sql = """
            delete from \(kHandleNamesTable)
            where updated < ? and anonymous = 1
        """
        let threshold = Date().timeIntervalSince1970 - kHandleNameObsoleteThreshold
        executeUpdate(sql, args: [threshold])
    }
}

// MARK: SQL Execution Utility
private extension HandleNameManager {
    func executeQuery(_ sql: String, args: [Any], column: String) -> String? {
        guard let databaseQueue = databaseQueue else { return nil }
        var selected: String?
        databaseQueue.inDatabase { database in
            // log.debug(sql)
            guard let resultSet = database.executeQuery(sql, withArgumentsIn: args) else { return }
            while resultSet.next() {
                selected = resultSet.string(forColumn: column)
                break
            }
            resultSet.close()
        }
        return selected
    }

    func executeUpdate(_ sql: String, args: [Any]) {
        guard let databaseQueue = databaseQueue else { return }
        databaseQueue.inDatabase { database in
            // log.debug(sql)
            let success = database.executeUpdate(sql, withArgumentsIn: args)
            if !success {
                let message = String(describing: database.lastErrorMessage())
                log.error("failed to execute update: \(message)")
            }
        }
    }
}

// MARK: Database Instance Utility
private extension HandleNameManager {
    static func fullPathForHandleNamesDatabase() -> String {
        return LoggerHelper.applicationDirectoryPath() + "/" + kHandleNamesDatabase
    }

    static func databaseForHandleNames() -> FMDatabase? {
        let database = FMDatabase(path: HandleNameManager.fullPathForHandleNamesDatabase())
        guard database.open() == true else {
            log.error("unable to open database")
            return nil
        }
        return database
    }

    static func databaseQueueForHandleNames() -> FMDatabaseQueue? {
        return FMDatabaseQueue(path: HandleNameManager.fullPathForHandleNamesDatabase())
    }
}
