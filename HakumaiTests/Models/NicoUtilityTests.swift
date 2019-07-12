//
//  NicoUtilityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/14/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

private let kAsyncTimeout: TimeInterval = 3

final class NicoUtilityTests: XCTestCase {

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

        parameters = NicoUtility.shared.construct(parameters: nil)
        XCTAssert(parameters == nil, "")

        parameters = NicoUtility.shared.construct(parameters: ["a": "b"])
        XCTAssert(parameters == "a=b", "")

        parameters = NicoUtility.shared.construct(parameters: ["a": 123])
        XCTAssert(parameters == "a=123", "")

        parameters = NicoUtility.shared.construct(parameters: ["a": "b", "c": "d"])
        // XCTAssert(parameters == "a=b&c=d", "")

        // space
        parameters = NicoUtility.shared.construct(parameters: ["a": "b c"])
        XCTAssert(parameters == "a=b%20c", "")

        // symbol in ngscoring
        parameters = NicoUtility.shared.construct(parameters: ["tpos": "1416842780.802121", "comment_locale": "ja-jp"])
        // XCTAssert(parameters == "tpos=1416842780%2E802121&comment%5Flocale=ja%2Djp", "")
        // XCTAssert(parameters == "comment%5Flocale=ja%2Djp&tpos=1416842780%2E802121", "")
    }

    // MARK: - Room Position
    func testRoomPosition() {
        let user = User()

        user.roomLabel = "x"
        XCTAssert(NicoUtility.shared.roomPosition(byUser: user) == nil, "")

        user.roomLabel = "co123"
        XCTAssert(NicoUtility.shared.roomPosition(byUser: user) == .arena, "")

        user.roomLabel = "ch123"
        XCTAssert(NicoUtility.shared.roomPosition(byUser: user) == .arena, "")

        user.roomLabel = "バックステージパス"
        XCTAssert(NicoUtility.shared.roomPosition(byUser: user) == .arena, "")

        user.roomLabel = "立ち見1"
        XCTAssert(NicoUtility.shared.roomPosition(byUser: user) == .standA, "")

        user.roomLabel = "立ち見3"
        XCTAssert(NicoUtility.shared.roomPosition(byUser: user) == .standC, "")
    }

    func testDeriveMessageServersUser() {
        var expected: [MessageServer]
        var derived: [MessageServer]

        let community = Community()
        community.community = "co12345"

        let server0 = MessageServer(roomPosition: .arena, address: "msg102.live.nicovideo.jp", port: 2820, thread: 100)
        let server1 = MessageServer(roomPosition: .standA, address: "msg103.live.nicovideo.jp", port: 2830, thread: 101)
        let server2 = MessageServer(roomPosition: .standB, address: "msg104.live.nicovideo.jp", port: 2840, thread: 102)
        let server3 = MessageServer(roomPosition: .standC, address: "msg105.live.nicovideo.jp", port: 2850, thread: 103)
        let server4 = MessageServer(roomPosition: .standD, address: "msg101.live.nicovideo.jp", port: 2811, thread: 104)
        let server5 = MessageServer(roomPosition: .standE, address: "msg102.live.nicovideo.jp", port: 2821, thread: 105)
        let server6 = MessageServer(roomPosition: .standF, address: "msg103.live.nicovideo.jp", port: 2831, thread: 106)
        let server7 = MessageServer(roomPosition: .standG, address: "msg104.live.nicovideo.jp", port: 2841, thread: 107)
        let server8 = MessageServer(roomPosition: .standH, address: "msg105.live.nicovideo.jp", port: 2851, thread: 108)
        let server9 = MessageServer(roomPosition: .standI, address: "msg101.live.nicovideo.jp", port: 2812, thread: 109)

        // level 999
        community.level = 999
        expected = [server0, server1, server2, server3, server4, server5, server6, server7, server8, server9]
        print("expected:\(expected)")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server0, community: community)
        print("derived:\(derived)")
        XCTAssert(derived == expected, "")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server1, community: community)
        XCTAssert(derived == expected, "")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server3, community: community)
        XCTAssert(derived == expected, "")

        // level 65
        community.level = 49
        expected = [server0, server1]

        derived = NicoUtility.shared.deriveMessageServers(originServer: server0, community: community)
        XCTAssert(derived == expected, "")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server1, community: community)
        XCTAssert(derived == expected, "")

        // level 66
        community.level = 50
        expected = [server0, server1, server2]

        derived = NicoUtility.shared.deriveMessageServers(originServer: server0, community: community)
        XCTAssert(derived == expected, "")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server1, community: community)
        XCTAssert(derived == expected, "")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server2, community: community)
        XCTAssert(derived == expected, "")
    }

    func testDeriveMessageServersChannel() {
        var expected: [MessageServer]
        var derived: [MessageServer]

        let community = Community()
        community.community = "ch12345"

        let server0 = MessageServer(roomPosition: .arena, address: "omsg101.live.nicovideo.jp", port: 2815, thread: 100)
        let server1 = MessageServer(roomPosition: .standA, address: "omsg102.live.nicovideo.jp", port: 2828, thread: 101)
        let server2 = MessageServer(roomPosition: .standB, address: "omsg103.live.nicovideo.jp", port: 2841, thread: 102)
        let server3 = MessageServer(roomPosition: .standC, address: "omsg104.live.nicovideo.jp", port: 2854, thread: 103)
        let server4 = MessageServer(roomPosition: .standD, address: "omsg105.live.nicovideo.jp", port: 2867, thread: 104)
        let server5 = MessageServer(roomPosition: .standE, address: "omsg106.live.nicovideo.jp", port: 2880, thread: 105)

        expected = [server0, server1, server2, server3, server4, server5]
        print("expected:\(expected)")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server0, community: community)
        print("derived:\(derived)")
        XCTAssert(derived == expected, "")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server1, community: community)
        XCTAssert(derived == expected, "")

        derived = NicoUtility.shared.deriveMessageServers(originServer: server3, community: community)
        XCTAssert(derived == expected, "")
    }

    // MARK: - Community
    func testLoadCommunityUser() {
        let data = dataForResource("community_user.html")
        let community = Community()

        NicoUtility.shared.extractUserCommunity(fromHtmlData: data, community: community)
        XCTAssert(community.title == "深淵の帰還", "")
        XCTAssert(community.level == 53, "")
        XCTAssert(community.thumbnailUrl!.absoluteString == "http://icon.nimg.jp/community/335/co3350558.jpg?1474545332", "")
    }

    func testLoadCommunityChannel() {
        let data = dataForResource("community_channel.html")
        let community = Community()

        NicoUtility.shared.extractChannelCommunity(fromHtmlData: data, community: community)
        XCTAssert(community.title == "暗黒黙示録", "")
        XCTAssert(community.level == nil, "")
        XCTAssert(community.thumbnailUrl!.absoluteString == "http://icon.nimg.jp/channel/ch2590739.jpg?1411539979", "")
    }

    func testStandRoomCountForCommunityLevel() {
        XCTAssert(NicoUtility.shared.standRoomCount(forCommunityLevel: 49) == 1, "")
        XCTAssert(NicoUtility.shared.standRoomCount(forCommunityLevel: 50) == 2, "")

        XCTAssert(NicoUtility.shared.standRoomCount(forCommunityLevel: 104) == 3, "")
        XCTAssert(NicoUtility.shared.standRoomCount(forCommunityLevel: 105) == 4, "")
    }

    // MARK: - Username Resolver
    func testExtractUsername() {
        var data: Data!
        var resolved: String?

        data = dataForResource("user_1.html")
        resolved = NicoUtility.shared.extractUsername(fromHtmlData: data)
        XCTAssert(resolved == "野田草履", "")

        // should extract ナオキ兄さん, not ナオキ兄
        data = dataForResource("user_2.html")
        resolved = NicoUtility.shared.extractUsername(fromHtmlData: data)
        XCTAssert(resolved == "ナオキ兄さん", "")

        data = dataForResource("user_me.html")
        resolved = NicoUtility.shared.extractUsername(fromHtmlData: data)
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
        var data: Data!
        var hb: Heartbeat?

        data = dataForResource("heartbeat_ok.xml")
        hb = NicoUtility.shared.extractHeartbeat(fromXmlData: data)
        XCTAssert(hb?.status == Heartbeat.Status.ok, "")

        data = dataForResource("heartbeat_fail.xml")
        hb = NicoUtility.shared.extractHeartbeat(fromXmlData: data)
        XCTAssert(hb?.status == Heartbeat.Status.fail, "")
        XCTAssert(hb?.errorCode == Heartbeat.ErrorCode.notFoundSlot, "")
    }

    // MARK: - Test Utility
    func dataForResource(_ fileName: String) -> Data {
        let bundle = Bundle(for: NicoUtilityTests.self)
        let path = bundle.path(forResource: fileName, ofType: nil)
        let fileHandle = FileHandle(forReadingAtPath: path!)
        let data = fileHandle?.readDataToEndOfFile()

        return data!
    }
}
