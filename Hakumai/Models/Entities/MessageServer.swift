//
//  MessageServer.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kRegExpPatternHostUser = "msg\\d+\\..+"
private let kRegExpPatternHostChannel = "omsg\\d+\\..+"

private let kMessageServerNumberFirst = 101
private let kMessageServerNumberLast = 104

private let kMessageServerPortFirstUser = 2805
private let kMessageServerPortLastUser = 2814

private let kMessageServerPortFirstChannel = 2815
private let kMessageServerPortLastChannel = 2817

class MessageServer: Printable {
    let roomPosition: RoomPosition
    let address: String
    let port: Int
    let thread: Int
    
    var isChannel: Bool {
        if self.address.hasRegexpPattern(kRegExpPatternHostChannel) {
            return true
        }
        
        // skip to examine kRegExpPatternHostUser, default live type is 'user'
        return false
    }
    
    var description: String {
        return (
            "MessageServer: roomPosition[\(self.roomPosition)] " +
            "address[\(self.address)] port[\(self.port)] thread[\(self.thread)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init(roomPosition: RoomPosition, address: String, port: Int, thread: Int) {
        self.roomPosition = roomPosition
        self.address = address
        self.port = port
        self.thread = thread
    }

    // MARK: - Public Functions
    func previous() -> MessageServer {
        let roomPosition = RoomPosition(rawValue: self.roomPosition.rawValue - 1)
        var address = self.address
        var port = self.port
        let thread = self.thread - 1

        if self.isChannel {
            if let serverNumber = MessageServer.extractServerNumber(address) {
                if serverNumber == kMessageServerNumberFirst {
                    address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: kMessageServerNumberLast)
                    if port == kMessageServerPortFirstChannel {
                        port = kMessageServerPortLastChannel
                    }
                    else {
                        port -= 1
                    }
                }
                else {
                    address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: serverNumber - 1)
                }
            }
        }
        else {
            if port == kMessageServerPortFirstUser {
                port = kMessageServerPortLastUser
                
                if let serverNumber = MessageServer.extractServerNumber(address) {
                    if serverNumber == kMessageServerNumberFirst {
                        address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: kMessageServerNumberLast)
                    }
                    else {
                        address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: serverNumber - 1)
                    }
                }
            }
            else {
                port -= 1
            }
        }
        
        return MessageServer(roomPosition: roomPosition!, address: address, port: port, thread: thread)
    }
    
    func next() -> MessageServer {
        let roomPosition = RoomPosition(rawValue: self.roomPosition.rawValue + 1)
        var address = self.address
        var port = self.port
        let thread = self.thread + 1
        
        if self.isChannel {
            if let serverNumber = MessageServer.extractServerNumber(address) {
                if serverNumber == kMessageServerNumberLast {
                    address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: kMessageServerNumberFirst)
                    if port == kMessageServerPortLastChannel {
                        port = kMessageServerPortFirstChannel
                    }
                    else {
                        port += 1
                    }
                }
                else {
                    address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: serverNumber + 1)
                }
            }
        }
        else {
            if port == kMessageServerPortLastUser {
                port = kMessageServerPortFirstUser
                
                if let serverNumber = MessageServer.extractServerNumber(address) {
                    if serverNumber == kMessageServerNumberLast {
                        address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: kMessageServerNumberFirst)
                    }
                    else {
                        address = MessageServer.reconstructServerAddressWithBaseAddress(address, serverNumber: serverNumber + 1)
                    }
                }
            }
            else {
                port += 1
            }
        }
        
        return MessageServer(roomPosition: roomPosition!, address: address, port: port, thread: thread)
    }
    
    class func extractServerNumber(address: String) -> Int? {
        let regexp = "\\D+(\\d+).+"
        let serverNumber = address.extractRegexpPattern(regexp)
        
        return serverNumber?.toInt()
    }
    
    class func reconstructServerAddressWithBaseAddress(baseAddress: String, serverNumber: Int) -> String {
        // split server address like followings, and reconstruct using given server number
        // - msg102.live.nicovideo.jp (user)
        // - omsg103.live.nicovideo.jp (channel)
        let regexp = NSRegularExpression(pattern: "(\\D+)\\d+(.+)", options: nil, error: nil)!
        let matched = regexp.matchesInString(baseAddress, options: nil, range: NSMakeRange(0, count(baseAddress.utf16)))
        
        let hostPrefix = MessageServer.substringFromBaseString(baseAddress, nsRange: matched[0].rangeAtIndex(1))
        let domain = MessageServer.substringFromBaseString(baseAddress, nsRange: matched[0].rangeAtIndex(2))

        return hostPrefix + String(serverNumber) + domain
    }
    
    class func substringFromBaseString(base: String, nsRange: NSRange) -> String {
        let start = advance(base.startIndex, nsRange.location)
        let end = advance(base.startIndex, nsRange.location + nsRange.length)
        let range = Range<String.Index>(start: start, end: end)
        let substring = base.substringWithRange(range)
        
        return substring
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

func == (left: [MessageServer], right: [MessageServer]) -> Bool {
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
