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
        case Ok = 0
        case Fail
        
        var description: String {
            return kHeartbeatStatuses[rawValue]
        }
    }
    
    enum ErrorCode: Int, CustomStringConvertible {
        case NotFoundSlot = 0
        case NotFoundUserLiveSlot
        
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
            "Heartbeat: status[\(status)] errorCode[\(errorCode)] watchCount[\(watchCount)] " +
            "commentCount[\(commentCount)] freeSlotNum[\(freeSlotNum)] " +
            "isRestrict[\(isRestrict)] ticket[\(ticket)] waitTime[\(waitTime)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init() {
        // nop
    }
    
    // MARK: - Public Function
    class func statusFromString(status statusString: String) -> Heartbeat.Status? {
        var statusEnum: Heartbeat.Status?
        
        for var index = 0; index < kHeartbeatStatuses.count; index += 1 {
            if statusString == kHeartbeatStatuses[index] {
                statusEnum = Heartbeat.Status(rawValue: index)
                break
            }
        }
        
        return statusEnum
    }
    
    class func errorCodeFromString(errorCode errorCodeString: String) -> Heartbeat.ErrorCode? {
        var errorCodeEnum: Heartbeat.ErrorCode?
        
        for var index = 0; index < kHeartbeatErrorCodes.count; index += 1 {
            if errorCodeString == kHeartbeatErrorCodes[index] {
                errorCodeEnum = Heartbeat.ErrorCode(rawValue: index)
                break
            }
        }
        
        return errorCodeEnum
    }
}