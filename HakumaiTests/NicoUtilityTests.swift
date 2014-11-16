//
//  NicoUtilityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/14/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class NicoUtilityTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: room position
    func testRoomPosition() {
        var roomPosition: Int!
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("x")
        XCTAssert(roomPosition == nil, "")
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("co1")
        XCTAssert(roomPosition == 0, "")
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("立ち見A列")
        XCTAssert(roomPosition == 1, "")
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("立ち見C列")
        XCTAssert(roomPosition == 3, "")
    }
    
    func testServerNumber() {
        var serverNumber: Int!

        serverNumber = NicoUtility.getInstance().extractServerNumber("x")
        XCTAssert(serverNumber == nil, "")
        
        serverNumber = NicoUtility.getInstance().extractServerNumber("msg102.live.nicovideo.jp")
        XCTAssert(serverNumber == 102, "")
    }
    
    // message server specs:
    // user: msg[101-104].live.nicovideo.jp:[2805-2814]
    func testPreviousMessageServer() {
        var server: messageServer!
        var expected: messageServer!
        var previous: messageServer!
        
        server = messageServer(official: false, roomPosition: 1, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        expected = messageServer(official: false, roomPosition: 0, address: "msg102.live.nicovideo.jp", port: 2809, thread: 99)
        previous = NicoUtility.getInstance().previousMessageServer(server)
        XCTAssert(previous == expected, "")
        
        server = messageServer(official: false, roomPosition: 1, address: "msg102.live.nicovideo.jp", port: 2805, thread: 100)
        expected = messageServer(official: false, roomPosition: 0, address: "msg101.live.nicovideo.jp", port: 2814, thread: 99)
        previous = NicoUtility.getInstance().previousMessageServer(server)
        XCTAssert(previous == expected, "")

        server = messageServer(official: false, roomPosition: 1, address: "msg101.live.nicovideo.jp", port: 2805, thread: 100)
        expected = messageServer(official: false, roomPosition: 0, address: "msg104.live.nicovideo.jp", port: 2814, thread: 99)
        previous = NicoUtility.getInstance().previousMessageServer(server)
        XCTAssert(previous == expected, "")
    }
    
    func testNextMessageServer() {
        var server: messageServer!
        var expected: messageServer!
        var next: messageServer!
        
        server = messageServer(official: false, roomPosition: 1, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        expected = messageServer(official: false, roomPosition: 2, address: "msg102.live.nicovideo.jp", port: 2811, thread: 101)
        next = NicoUtility.getInstance().nextMessageServer(server)
        XCTAssert(next == expected, "")
        
        server = messageServer(official: false, roomPosition: 1, address: "msg102.live.nicovideo.jp", port: 2814, thread: 100)
        expected = messageServer(official: false, roomPosition: 2, address: "msg103.live.nicovideo.jp", port: 2805, thread: 101)
        next = NicoUtility.getInstance().nextMessageServer(server)
        XCTAssert(next == expected, "")
        
        server = messageServer(official: false, roomPosition: 1, address: "msg104.live.nicovideo.jp", port: 2814, thread: 100)
        expected = messageServer(official: false, roomPosition: 2, address: "msg101.live.nicovideo.jp", port: 2805, thread: 101)
        next = NicoUtility.getInstance().nextMessageServer(server)
        XCTAssert(next == expected, "")
    }
    
    func testDeriveMessageServer() {
        var server: messageServer!
        var expected: messageServer!
        var derived: messageServer!
        
        server = messageServer(official: false, roomPosition: 1, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        expected = messageServer(official: false, roomPosition: 3, address: "msg102.live.nicovideo.jp", port: 2812, thread: 102)
        derived = NicoUtility.getInstance().deriveMessageServer(server, distance: 2)
        XCTAssert(derived == expected, "")
        
        // TODO: more test cases should be implemented here
    }
    
    func testDeriveMessageServers() {
        var server: messageServer!
        var expected: Array<messageServer>
        var derived: Array<messageServer>
        
        let server0 = messageServer(official: false, roomPosition: 0, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        let server1 = messageServer(official: false, roomPosition: 1, address: "msg102.live.nicovideo.jp", port: 2811, thread: 101)
        let server2 = messageServer(official: false, roomPosition: 2, address: "msg102.live.nicovideo.jp", port: 2812, thread: 102)
        let server3 = messageServer(official: false, roomPosition: 3, address: "msg102.live.nicovideo.jp", port: 2813, thread: 103)
        let server4 = messageServer(official: false, roomPosition: 4, address: "msg102.live.nicovideo.jp", port: 2814, thread: 104)
        let server5 = messageServer(official: false, roomPosition: 5, address: "msg103.live.nicovideo.jp", port: 2805, thread: 105)
        let server6 = messageServer(official: false, roomPosition: 6, address: "msg103.live.nicovideo.jp", port: 2806, thread: 106)
        
        expected = [server0, server1, server2, server3, server4, server5, server6]
        println("expected:\(expected)")
        
        server = server0
        derived = NicoUtility.getInstance().deriveMessageServers(server)
        println("derived:\(derived)")
        XCTAssert(derived == expected, "")
        
        server = server1
        derived = NicoUtility.getInstance().deriveMessageServers(server)
        XCTAssert(derived == expected, "")
        
        server = server3
        derived = NicoUtility.getInstance().deriveMessageServers(server)
        XCTAssert(derived == expected, "")
    }
}
