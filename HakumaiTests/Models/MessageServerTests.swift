//
//  MessageServerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

final class MessageServerTests: XCTestCase {

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

        server = MessageServer(roomPosition: .arena, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        XCTAssert(server.isChannel == false, "")

        server = MessageServer(roomPosition: .arena, address: "omsg102.live.nicovideo.jp", port: 2810, thread: 100)
        XCTAssert(server.isChannel == true, "")
    }

    func testServerNumber() {
        var serverNumber: Int!

        serverNumber = MessageServer.extractServerNumber(fromAddress: "x")
        XCTAssert(serverNumber == nil, "")

        serverNumber = MessageServer.extractServerNumber(fromAddress: "msg102.live.nicovideo.jp")
        XCTAssert(serverNumber == 102, "")
    }

    // message server specs:
    // user: msg[101-104].live.nicovideo.jp:[2805-2814]
    func testPreviousMessageServer() {
        var server: MessageServer!
        var expected: MessageServer!
        var previous: MessageServer!

        server = MessageServer(roomPosition: .standA, address: "msg102.live.nicovideo.jp", port: 2820, thread: 100)
        expected = MessageServer(roomPosition: .arena, address: "msg101.live.nicovideo.jp", port: 2810, thread: 99)
        previous = server.previous()
        XCTAssert(previous == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg102.live.nicovideo.jp", port: 2815, thread: 100)
        expected = MessageServer(roomPosition: .arena, address: "msg101.live.nicovideo.jp", port: 2805, thread: 99)
        previous = server.previous()
        XCTAssert(previous == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg101.live.nicovideo.jp", port: 2805, thread: 100)
        expected = MessageServer(roomPosition: .arena, address: "msg105.live.nicovideo.jp", port: 2854, thread: 99)
        previous = server.previous()
        XCTAssert(previous == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg105.live.nicovideo.jp", port: 2852, thread: 100)
        expected = MessageServer(roomPosition: .arena, address: "msg104.live.nicovideo.jp", port: 2842, thread: 99)
        previous = server.previous()
        XCTAssert(previous == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg105.live.nicovideo.jp", port: 2845, thread: 100)
        expected = MessageServer(roomPosition: .arena, address: "msg104.live.nicovideo.jp", port: 2835, thread: 99)
        previous = server.previous()
        XCTAssert(previous == expected, "")
    }

    func testNextMessageServer() {
        var server: MessageServer!
        var expected: MessageServer!
        var next: MessageServer!

        server = MessageServer(roomPosition: .standA, address: "msg102.live.nicovideo.jp", port: 2815, thread: 100)
        expected = MessageServer(roomPosition: .standB, address: "msg103.live.nicovideo.jp", port: 2825, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg102.live.nicovideo.jp", port: 2824, thread: 100)
        expected = MessageServer(roomPosition: .standB, address: "msg103.live.nicovideo.jp", port: 2834, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg104.live.nicovideo.jp", port: 2844, thread: 100)
        expected = MessageServer(roomPosition: .standB, address: "msg105.live.nicovideo.jp", port: 2854, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg105.live.nicovideo.jp", port: 2852, thread: 100)
        expected = MessageServer(roomPosition: .standB, address: "msg101.live.nicovideo.jp", port: 2813, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")

        server = MessageServer(roomPosition: .standA, address: "msg105.live.nicovideo.jp", port: 2854, thread: 100)
        expected = MessageServer(roomPosition: .standB, address: "msg101.live.nicovideo.jp", port: 2805, thread: 101)
        next = server.next()
        XCTAssert(next == expected, "")
    }
}
