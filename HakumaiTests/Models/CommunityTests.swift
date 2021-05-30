//
//  CommunityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
@testable import Hakumai

final class CommunityTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIsChannel() {
        let channelCommunity = Community(
            communityId: "ch12345",
            title: "channel",
            level: 0,
            thumbnailUrl: nil
        )
        XCTAssert(channelCommunity.isChannel == true, "")

        let userCommunity = Community(
            communityId: "co12345",
            title: "user",
            level: 0,
            thumbnailUrl: nil
        )
        XCTAssert(userCommunity.isChannel == false, "")
    }
}
