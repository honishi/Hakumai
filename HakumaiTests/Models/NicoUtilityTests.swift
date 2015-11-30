//
//  NicoUtilityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/14/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

private let kAsyncTimeout: NSTimeInterval = 3

class NicoUtilityTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: - Internal Utility
    func testConstructParameters() {
        var parameters: String?
        
        parameters = NicoUtility.sharedInstance.constructParameters(nil)
        XCTAssert(parameters == nil, "")
        
        parameters = NicoUtility.sharedInstance.constructParameters(["a": "b"])
        XCTAssert(parameters == "a=b", "")
        
        parameters = NicoUtility.sharedInstance.constructParameters(["a": 123])
        XCTAssert(parameters == "a=123", "")
        
        parameters = NicoUtility.sharedInstance.constructParameters(["a": "b", "c": "d"])
        XCTAssert(parameters == "a=b&c=d", "")
        
        // space
        parameters = NicoUtility.sharedInstance.constructParameters(["a": "b c"])
        XCTAssert(parameters == "a=b%20c", "")
        
        // symbol in ngscoring
        parameters = NicoUtility.sharedInstance.constructParameters(["tpos": "1416842780.802121", "comment_locale": "ja-jp"])
        XCTAssert(parameters == "tpos=1416842780%2E802121&comment%5Flocale=ja%2Djp", "")
    }
    
    // MARK: - Room Position
    func testRoomPosition() {
        let user = User()

        user.roomLabel = "x"
        XCTAssert(NicoUtility.sharedInstance.roomPositionByUser(user) == nil, "")
        
        user.roomLabel = "co123"
        XCTAssert(NicoUtility.sharedInstance.roomPositionByUser(user) == .Arena, "")

        user.roomLabel = "ch123"
        XCTAssert(NicoUtility.sharedInstance.roomPositionByUser(user) == .Arena, "")

        user.roomLabel = "バックステージパス"
        XCTAssert(NicoUtility.sharedInstance.roomPositionByUser(user) == .Arena, "")

        user.roomLabel = "立ち見A列"
        XCTAssert(NicoUtility.sharedInstance.roomPositionByUser(user) == .StandA, "")

        user.roomLabel = "立ち見C列"
        XCTAssert(NicoUtility.sharedInstance.roomPositionByUser(user) == .StandC, "")
    }
    
    func testDeriveMessageServersUser() {
        var expected: [MessageServer]
        var derived: [MessageServer]
        
        let community = Community()
        community.community = "co12345"
        
        let server0 = MessageServer(roomPosition: .Arena, address: "msg102.live.nicovideo.jp", port: 2820, thread: 100)
        let server1 = MessageServer(roomPosition: .StandA, address: "msg103.live.nicovideo.jp", port: 2830, thread: 101)
        let server2 = MessageServer(roomPosition: .StandB, address: "msg104.live.nicovideo.jp", port: 2840, thread: 102)
        let server3 = MessageServer(roomPosition: .StandC, address: "msg101.live.nicovideo.jp", port: 2811, thread: 103)
        let server4 = MessageServer(roomPosition: .StandD, address: "msg102.live.nicovideo.jp", port: 2821, thread: 104)
        let server5 = MessageServer(roomPosition: .StandE, address: "msg103.live.nicovideo.jp", port: 2831, thread: 105)
        let server6 = MessageServer(roomPosition: .StandF, address: "msg104.live.nicovideo.jp", port: 2841, thread: 106)
        let server7 = MessageServer(roomPosition: .StandG, address: "msg101.live.nicovideo.jp", port: 2812, thread: 107)

        // level 999
        community.level = 999
        expected = [server0, server1, server2, server3, server4, server5, server6, server7]
        print("expected:\(expected)")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server0, community: community)
        print("derived:\(derived)")
        XCTAssert(derived == expected, "")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server1, community: community)
        XCTAssert(derived == expected, "")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server3, community: community)
        XCTAssert(derived == expected, "")
        
        // level 65
        community.level = 65
        expected = [server0, server1]
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server0, community: community)
        XCTAssert(derived == expected, "")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server1, community: community)
        XCTAssert(derived == expected, "")
        
        // level 66
        community.level = 66
        expected = [server0, server1, server2]
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server0, community: community)
        XCTAssert(derived == expected, "")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server1, community: community)
        XCTAssert(derived == expected, "")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server2, community: community)
        XCTAssert(derived == expected, "")
    }
    
    func testDeriveMessageServersChannel() {
        var expected: [MessageServer]
        var derived: [MessageServer]
        
        let community = Community()
        community.community = "ch12345"
        
        let server0 = MessageServer(roomPosition: .Arena, address: "omsg101.live.nicovideo.jp", port: 2815, thread: 100)
        let server1 = MessageServer(roomPosition: .StandA, address: "omsg102.live.nicovideo.jp", port: 2828, thread: 101)
        let server2 = MessageServer(roomPosition: .StandB, address: "omsg103.live.nicovideo.jp", port: 2841, thread: 102)
        let server3 = MessageServer(roomPosition: .StandC, address: "omsg104.live.nicovideo.jp", port: 2854, thread: 103)
        let server4 = MessageServer(roomPosition: .StandD, address: "omsg105.live.nicovideo.jp", port: 2867, thread: 104)
        let server5 = MessageServer(roomPosition: .StandE, address: "omsg106.live.nicovideo.jp", port: 2880, thread: 105)
        
        expected = [server0, server1, server2, server3, server4, server5]
        print("expected:\(expected)")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server0, community: community)
        print("derived:\(derived)")
        XCTAssert(derived == expected, "")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server1, community: community)
        XCTAssert(derived == expected, "")
        
        derived = NicoUtility.sharedInstance.deriveMessageServersWithOriginServer(server3, community: community)
        XCTAssert(derived == expected, "")
    }
    
    // MARK: - Community
    func testLoadCommunityUser() {
        let data = dataForResource("community_user.html")
        let community = Community()
        
        NicoUtility.sharedInstance.extractUserCommunity(data, community: community)
        XCTAssert(community.title == "野田草履のからし高菜炎上", "")
        XCTAssert(community.level == 109, "")
        XCTAssert(community.thumbnailUrl!.absoluteString == "http://icon.nimg.jp/community/135/co1354854.jpg?1412118337", "")
    }
    
    func testLoadCommunityChannel() {
        let data = dataForResource("community_channel.html")
        let community = Community()
        
        NicoUtility.sharedInstance.extractChannelCommunity(data, community: community)
        XCTAssert(community.title == "暗黒黙示録", "")
        XCTAssert(community.level == nil, "")
        XCTAssert(community.thumbnailUrl!.absoluteString == "http://icon.nimg.jp/channel/ch2590739.jpg?1411539979", "")
    }
    
    func testStandRoomCountForCommunityLevel() {
        XCTAssert(NicoUtility.sharedInstance.standRoomCountForCommunityLevel(65) == 1, "")
        XCTAssert(NicoUtility.sharedInstance.standRoomCountForCommunityLevel(66) == 2, "")
        
        XCTAssert(NicoUtility.sharedInstance.standRoomCountForCommunityLevel(104) == 3, "")
        XCTAssert(NicoUtility.sharedInstance.standRoomCountForCommunityLevel(105) == 4, "")
    }
    
    // MARK: - Username Resolver
    func testExtractUsername() {
        var data: NSData!
        var resolved: String?
        
        data = dataForResource("user_1.html")
        resolved = NicoUtility.sharedInstance.extractUsername(data)
        XCTAssert(resolved == "野田草履", "")
        
        // should extract ナオキ兄さん, not ナオキ兄
        data = dataForResource("user_2.html")
        resolved = NicoUtility.sharedInstance.extractUsername(data)
        XCTAssert(resolved == "ナオキ兄さん", "")
        
        data = dataForResource("user_me.html")
        resolved = NicoUtility.sharedInstance.extractUsername(data)
        XCTAssert(resolved == "honishi", "")
    }
    
    /*
    func testResolveUsername() {
        var asyncExpectation: XCTestExpectation
        
        // raw id case
        asyncExpectation = expectationWithDescription("asyncExpectation")
        
        NicoUtility.sharedInstance.resolveUsername("79595", completion: { (userName) -> Void in
            // test: NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: NSTimeInterval(5)))
            
            XCTAssert(userName == "honishi", "")
            asyncExpectation.fulfill()
        })

        waitForExpectationsWithTimeout(kAsyncTimeout, handler: nil)
        
        // 184 id case
        asyncExpectation = expectationWithDescription("asyncExpectation")
        
        NicoUtility.sharedInstance.resolveUsername("abc", completion: { (userName) -> (Void) in
            XCTAssert(userName == nil, "")
            asyncExpectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(kAsyncTimeout, handler: nil)
    }
     */

    // MARK: - Heartbeat
    func testExtractHeartbeat() {
        var data: NSData!
        var hb: Heartbeat?
        
        data = dataForResource("heartbeat_ok.xml")
        hb = NicoUtility.sharedInstance.extractHeartbeat(data)
        XCTAssert(hb?.status == Heartbeat.Status.Ok, "")
        
        data = dataForResource("heartbeat_fail.xml")
        hb = NicoUtility.sharedInstance.extractHeartbeat(data)
        XCTAssert(hb?.status == Heartbeat.Status.Fail, "")
        XCTAssert(hb?.errorCode == Heartbeat.ErrorCode.NotFoundSlot, "")
    }
    
    // MARK: - Test Utility
    func dataForResource(fileName: String) -> NSData {
        let bundle = NSBundle(forClass: NicoUtilityTests.self)
        let path = bundle.pathForResource(fileName, ofType: nil)
        let fileHandle = NSFileHandle(forReadingAtPath: path!)
        let data = fileHandle?.readDataToEndOfFile()
        
        return data!
    }
}
