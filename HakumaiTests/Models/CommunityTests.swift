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
        let community: Community = Community()

        community.community = "ch12345"
        XCTAssert(community.isChannel == true, "")

        community.community = "co12345"
        XCTAssert(community.isChannel == false, "")
    }
}
