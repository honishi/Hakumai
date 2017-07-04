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
        case success = 0
        case failure
        case invalidThread
        case invalidTicket
        case invalidPostkey
        case locked
        case readOnly
        case tooLong
        
        var description: String {
            return "ChatResult.Status: \(rawValue)(\(label()))"
        }
        
        func label() -> String {
            switch (self) {
            case .success:
                return "Success"
            case .failure:
                return "Failure"
            case .invalidThread:
                return "InvalidThread"
            case .invalidTicket:
                return "InvalidTicket"
            case .invalidPostkey:
                return "InvalidPostkey"
            case .locked:
                return "Locked"
            case .readOnly:
                return "ReadOnly"
            case .tooLong:
                return "TooLong"
            }
        }
    }
    
    var status: Status?
    
    var description: String {
        return (
            "ChatResult: status[\(status?.description ?? "")]"
        )
    }

    // MARK: - Object Lifecycle
    init() {
        // nop
    }
}
