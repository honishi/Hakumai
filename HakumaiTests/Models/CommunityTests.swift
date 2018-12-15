//
//  CommunityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

final class CommunityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
