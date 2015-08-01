//
//  MessageServerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class MessageServerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testIsChannel() {
        var server: MessageServer!
        
        server = MessageServer(roomPosition: .Arena, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        XCTAssert(server.isChannel == false, "")
        
        server = MessageServer(roomPosition: .Arena, address: "omsg102.live.nicovideo.jp", port: 2810, thread: 100)
        XCTAssert(server.isChannel == true, "")
    }
    
    func testServerNumber() {
        var serverNumber: Int!
        
        serverNumber = MessageServer.extractServerNumber("x")
        XCTAssert(serverNumber == nil, "")
        
        serverNumber = MessageServer.extractServerNumber("msg102.live.nicovideo.jp")
        XCTAssert(serverNumber == 102, "")
    }
    
    // message server specs:
    // user: msg[101-104].live.nicovideo.jp:[2805-2814]
    func testPreviousMessageServer() {
        var server: MessageServer!
        var expected: MessageServer!
        var previous: MessageServer!
        
        server = MessageServer(roomPosition: .StandA, address: "msg102.live.nicovideo.jp", port: 2820, thread: 100)
        expected = MessageServer(roomPosition: .Arena, address: "msg102.live.nicovideo.jp", port: 2819, thread: 99)
        previous = server.previous()
        XCTAssert(previous == expected, "")
        
        server = MessageServer(roomPosition: .StandA, address: "msg102.live.nicovideo.jp", port: 2815, thread: 100)
        expected = MessageServer(roomPosition: .Arena, address: "msg101.live.nicovideo.jp", port: 2814, thread: 99)
        previous = server.previous()
        XCTAssert(previous == expected, "")
        
        server = MessageServer(roomPosition: .StandA, address: "msg101.live.nicovideo.jp", port: 2805, thread: 100)
        expected = MessageServer(roomPosition: .Arena, address: "msg105.live.nicovideo.jp", port: 2854, thread: 99)
        previous = server.previous()
        
        server = MessageServer(roomPosition: .StandA, address: "msg105.live.nicovideo.jp", port: 2852, thread: 100)
        expected = MessageServer(roomPosition: .Arena, address: "msg105.live.nicovideo.jp", port: 2851, thread: 99)
        previous = server.previous()

        server = MessageServer(roomPosition: .StandA, address: "msg105.live.nicovideo.jp", port: 2845, thread: 100)
        expected = MessageServer(roomPosition: .Arena, address: "msg104.live.nicovideo.jp", port: 2844, thread: 99)
        previous = server.previous()
        
        XCTAssert(previous == expected, "")
    }
    
    func testNextMessageServer() {
        var server: MessageServer!
        var expected: MessageServer!
        var next: MessageServer!
        
        server = MessageServer(roomPosition: .StandA, address: "msg102.live.nicovideo.jp", port: 2815, thread: 100)
        expected = MessageServer(roomPosition: .StandB, address: "msg102.live.nicovideo.jp", port: 2816, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")
        
        server = MessageServer(roomPosition: .StandA, address: "msg102.live.nicovideo.jp", port: 2824, thread: 100)
        expected = MessageServer(roomPosition: .StandB, address: "msg103.live.nicovideo.jp", port: 2825, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")
        
        server = MessageServer(roomPosition: .StandA, address: "msg104.live.nicovideo.jp", port: 2844, thread: 100)
        expected = MessageServer(roomPosition: .StandB, address: "msg105.live.nicovideo.jp", port: 2845, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")
        
        server = MessageServer(roomPosition: .StandA, address: "msg105.live.nicovideo.jp", port: 2852, thread: 100)
        expected = MessageServer(roomPosition: .StandB, address: "msg105.live.nicovideo.jp", port: 2853, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")

        server = MessageServer(roomPosition: .StandA, address: "msg105.live.nicovideo.jp", port: 2854, thread: 100)
        expected = MessageServer(roomPosition: .StandB, address: "msg101.live.nicovideo.jp", port: 2805, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")
    }
}