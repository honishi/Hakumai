//
//  ChatResult.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class ChatResult {
    enum Status: Int, CustomStringConvertible {
        case Success = 0
        case Failure
        case InvalidThread
        case InvalidTicket
        case InvalidPostkey
        case Locked
        case ReadOnly
        case TooLong
        
        var description: String {
            return "ChatResult.Status: \(self.rawValue)(\(self.label()))"
        }
        
        func label() -> String {
            switch (self) {
            case .Success:
                return "Success"
            case .Failure:
                return "Failure"
            case .InvalidThread:
                return "InvalidThread"
            case .InvalidTicket:
                return "InvalidTicket"
            case .InvalidPostkey:
                return "InvalidPostkey"
            case .Locked:
                return "Locked"
            case .ReadOnly:
                return "ReadOnly"
            case .TooLong:
                return "TooLong"
            }
        }
    }
    
    var status: Status?
    
    var description: String {
        return (
            "ChatResult: status[\(self.status)]"
        )
    }

    // MARK: - Object Lifecycle
    init() {
        // nop
    }
}