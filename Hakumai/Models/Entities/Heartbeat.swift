//
//  Heatbeat.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/8/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kHeartbeatStatuses = [
    "ok",
    "fail"]

private let kHeartbeatErrorCodes = [
    "NOTFOUND_SLOT",
    "NOTFOUND_USERLIVESLOT"]

class Heartbeat: CustomStringConvertible {
    // MARK: - Enums
    enum Status: Int, CustomStringConvertible {
        case ok = 0
        case fail
        
        var description: String {
            return kHeartbeatStatuses[rawValue]
        }
    }
    
    enum ErrorCode: Int, CustomStringConvertible {
        case notFoundSlot = 0
        case notFoundUserLiveSlot
        
        var description: String {
            return kHeartbeatErrorCodes[rawValue]
        }
    }
    
    // MARK: - Properties
    var status: Heartbeat.Status?
    var errorCode: Heartbeat.ErrorCode?
    
    var watchCount: Int?
    var commentCount: Int?
    var freeSlotNum: Int?
    var isRestrict: Int?
    var ticket: String?
    var waitTime: Int?
    
    var description: String {
        return (
            "Heartbeat: status[\(status?.description ?? "")] errorCode[\(errorCode?.description ?? "")] watchCount[\(watchCount ?? 0)] " +
            "commentCount[\(commentCount ?? 0)] freeSlotNum[\(freeSlotNum ?? 0)] " +
            "isRestrict[\(isRestrict ?? 0)] ticket[\(ticket ?? "")] waitTime[\(waitTime ?? 0)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init() {
        // nop
    }
    
    // MARK: - Public Function
    static func statusFromString(status statusString: String) -> Heartbeat.Status? {
        var statusEnum: Heartbeat.Status?
        
        for index in 0 ..< kHeartbeatStatuses.count {
            if statusString == kHeartbeatStatuses[index] {
                statusEnum = Heartbeat.Status(rawValue: index)
                break
            }
        }
        
        return statusEnum
    }
    
    static func errorCodeFromString(errorCode errorCodeString: String) -> Heartbeat.ErrorCode? {
        var errorCodeEnum: Heartbeat.ErrorCode?
        
        for index in 0 ..< kHeartbeatErrorCodes.count {
            if errorCodeString == kHeartbeatErrorCodes[index] {
                errorCodeEnum = Heartbeat.ErrorCode(rawValue: index)
                break
            }
        }
        
        return errorCodeEnum
    }
}
