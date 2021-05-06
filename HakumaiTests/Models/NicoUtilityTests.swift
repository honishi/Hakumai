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

    // MARK: - Comment Server Info
    func testExtractCommentServerInfo() {
        let html = dataForResource("live_page.html")
        let extracted = NicoUtility.extractWebSocketUrlFromLivePage(html: html)
        XCTAssert(extracted == "wss://a.live2.nicovideo.jp/unama/wsapi/v2/watch/12345?audience_token=12345_12345_12345_abcde")
    }

    // MARK: - Community
    /* func testLoadCommunityUser() {
     let data = dataForResource("community_user.html")
     let community = Community()

     NicoUtility.shared.extractUserCommunity(fromHtmlData: data, community: community)
     XCTAssert(community.title == "深淵の帰還", "")
     XCTAssert(community.level == 53, "")
     XCTAssert(community.thumbnailUrl?.absoluteString == "http://icon.nimg.jp/community/335/co3350558.jpg?1474545332", "")
     }

     func testLoadCommunityChannel() {
     let data = dataForResource("community_channel.html")
     let community = Community()

     NicoUtility.shared.extractChannelCommunity(fromHtmlData: data, community: community)
     XCTAssert(community.title == "暗黒黙示録", "")
     XCTAssert(community.level == nil, "")
     XCTAssert(community.thumbnailUrl?.absoluteString == "http://icon.nimg.jp/channel/ch2590739.jpg?1411539979", "")
     } */

    // MARK: - Username Resolver
    func testExtractUsername() {
        var data: Data!
        var resolved: String?

        data = dataForResource("user_1.html")
        resolved = NicoUtility.shared.extractUsername(fromHtmlData: data)
        XCTAssert(resolved == "しみっちゃん", "")

        data = dataForResource("user_me.html")
        resolved = NicoUtility.shared.extractUsername(fromHtmlData: data)
        XCTAssert(resolved == "honishi", "")
    }

    // MARK: - Test Utility
    // swiftlint:disable force_unwrapping
    func dataForResource(_ fileName: String) -> Data {
        let bundle = Bundle(for: NicoUtilityTests.self)
        let path = bundle.path(forResource: fileName, ofType: nil)
        let fileHandle = FileHandle(forReadingAtPath: path!)
        let data = fileHandle?.readDataToEndOfFile()
        return data!
    }
    // swiftlint:enable force_unwrapping

    /* func stringForResource(_ fileName: String) -> String {
     let data = dataForResource(fileName)
     return String(data: data, encoding: .utf8)!
     } */
}
