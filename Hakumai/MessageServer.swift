//
//  MessageServer.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

let kMessageServerNumberFirst = 101
let kMessageServerNumberLast = 104
let kMessageServerPortOfficialFirst = 2815
let kMessageServerPortOfficialLast = 2817
let kMessageServerPortUserFirst = 2805
let kMessageServerPortUserLast = 2814

let kMessageServerAddressHostPrefix = "msg"
let kMessageServerAddressDomain = ".live.nicovideo.jp"

class MessageServer {
    let roomPosition: RoomPosition
    let address: String
    let port: Int
    let thread: Int
    
    init(roomPosition: RoomPosition, address: String, port: Int, thread: Int) {
        self.roomPosition = roomPosition
        self.address = address
        self.port = port
        self.thread = thread
    }
    
    func isOfficial() -> Bool {
        // TODO:
        return false
    }
    
    func previous() -> MessageServer {
        let roomPosition = RoomPosition(rawValue: self.roomPosition.rawValue - 1)
        var address = self.address
        var port = self.port
        let thread = self.thread - 1
        
        if port == kMessageServerPortUserFirst {
            port = kMessageServerPortUserLast
            
            if let serverNumber = MessageServer.extractServerNumber(address) {
                if serverNumber == kMessageServerNumberFirst {
                    address = MessageServer.serverAddressWithServerNumber(kMessageServerNumberLast)
                }
                else {
                    address = MessageServer.serverAddressWithServerNumber(serverNumber - 1)
                }
            }
        }
        else {
            port -= 1
        }
        
        return MessageServer(roomPosition: roomPosition!, address: address, port: port, thread: thread)
    }
    
    func next() -> MessageServer {
        let roomPosition = RoomPosition(rawValue: self.roomPosition.rawValue + 1)
        var address = self.address
        var port = self.port
        let thread = self.thread + 1
        
        if port == kMessageServerPortUserLast {
            port = kMessageServerPortUserFirst
            
            if let serverNumber = MessageServer.extractServerNumber(address) {
                if serverNumber == kMessageServerNumberLast {
                    address = MessageServer.serverAddressWithServerNumber(kMessageServerNumberFirst)
                }
                else {
                    address = MessageServer.serverAddressWithServerNumber(serverNumber + 1)
                }
            }
        }
        else {
            port += 1
        }
        
        return MessageServer(roomPosition: roomPosition!, address: address, port: port, thread: thread)
    }
    
    class func extractServerNumber(address: String) -> Int? {
        let regexp = kMessageServerAddressHostPrefix + "(\\d+)" + kMessageServerAddressDomain
        let serverNumber = address.extractRegexpPattern(regexp)
        
        return serverNumber?.toInt()
    }
    
    class func serverAddressWithServerNumber(serverNumber: Int) -> String {
        return kMessageServerAddressHostPrefix + String(serverNumber) + kMessageServerAddressDomain
    }
}

// this overload is used in test methods
func == (left: MessageServer, right: MessageServer) -> Bool {
    return (left.roomPosition == right.roomPosition &&
        left.address == right.address &&
        left.port == right.port &&
        left.thread == right.thread)
}

func != (left: MessageServer, right: MessageServer) -> Bool {
    return !(left == right)
}

func == (left: Array<MessageServer>, right: Array<MessageServer>) -> Bool {
    if left.count != right.count {
        return false
    }
    
    for i in 0..<left.count {
        if left[i] != right[i] {
            return false
        }
    }
    
    return true
}
