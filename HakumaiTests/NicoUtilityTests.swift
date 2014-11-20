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
        var roomPosition: RoomPosition?
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("x")
        XCTAssert(roomPosition == nil, "")
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("co1")
        XCTAssert(roomPosition == .Arena, "")
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("立ち見A列")
        XCTAssert(roomPosition == .StandA, "")
        
        roomPosition = NicoUtility.getInstance().roomPositionByRoomLabel("立ち見C列")
        XCTAssert(roomPosition == .StandC, "")
    }
    
    func testDeriveMessageServer() {
        var server: MessageServer!
        var expected: MessageServer!
        var derived: MessageServer!
        
        server = MessageServer(roomPosition: .StandA, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        expected = MessageServer(roomPosition: .StandC, address: "msg102.live.nicovideo.jp", port: 2812, thread: 102)
        derived = NicoUtility.getInstance().deriveMessageServer(server, distance: 2)
        XCTAssert(derived == expected, "")
        
        // TODO: more test cases should be implemented here
    }
    
    func testDeriveMessageServers() {
        var server: MessageServer!
        var expected: Array<MessageServer>
        var derived: Array<MessageServer>
        
        let server0 = MessageServer(roomPosition: .Arena, address: "msg102.live.nicovideo.jp", port: 2810, thread: 100)
        let server1 = MessageServer(roomPosition: .StandA, address: "msg102.live.nicovideo.jp", port: 2811, thread: 101)
        let server2 = MessageServer(roomPosition: .StandB, address: "msg102.live.nicovideo.jp", port: 2812, thread: 102)
        let server3 = MessageServer(roomPosition: .StandC, address: "msg102.live.nicovideo.jp", port: 2813, thread: 103)
        let server4 = MessageServer(roomPosition: .StandD, address: "msg102.live.nicovideo.jp", port: 2814, thread: 104)
        let server5 = MessageServer(roomPosition: .StandE, address: "msg103.live.nicovideo.jp", port: 2805, thread: 105)
        let server6 = MessageServer(roomPosition: .StandF, address: "msg103.live.nicovideo.jp", port: 2806, thread: 106)
        
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
    
    // MARK: - community
    func testCheckCommunityLevel() {
        let data = self.dataForResource("community.html")
        
        let level = NicoUtility.getInstance().extractCommunityLevel(data)
        XCTAssert(level == 109, "")
    }
    
    func testCanOpenRoomPosition() {
        var roomPosition: RoomPosition = .Arena
        var canOpen: Bool?
        
        roomPosition = RoomPosition.StandB
        canOpen = NicoUtility.getInstance().canOpenRoomPosition(roomPosition, communityLevel: 65)
        XCTAssert(canOpen == false, "")
        canOpen = NicoUtility.getInstance().canOpenRoomPosition(roomPosition, communityLevel: 66)
        XCTAssert(canOpen == true, "")
        
        roomPosition = RoomPosition.StandD
        canOpen = NicoUtility.getInstance().canOpenRoomPosition(roomPosition, communityLevel: 104)
        XCTAssert(canOpen == false, "")
        canOpen = NicoUtility.getInstance().canOpenRoomPosition(roomPosition, communityLevel: 105)
        XCTAssert(canOpen == true, "")
    }
    
    // MARK: - test utility
    func dataForResource(fileName: String) -> NSData {
        let bundle = NSBundle(forClass: NicoUtilityTests.self)
        let path = bundle.pathForResource(fileName, ofType: nil)
        let fileHandle = NSFileHandle(forReadingAtPath: path!)
        let data = fileHandle?.readDataToEndOfFile()
        
        return data!
    }
}
