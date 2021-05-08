//
//  ChatTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

final class ChatTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIsRawUserId() {
        XCTAssert(Chat.isRawUserId("123") == true, "")
        XCTAssert(Chat.isRawUserId("123a") == false, "")
        XCTAssert(Chat.isRawUserId(nil) == false, "")
    }

    func testIsUserComment() {
        XCTAssert(Chat.isUserComment(Premium.ippan) == true, "")
        XCTAssert(Chat.isUserComment(Premium.premium) == true, "")
        XCTAssert(Chat.isUserComment(Premium.bsp) == false, "")
        XCTAssert(Chat.isUserComment(Premium.system) == false, "")
        XCTAssert(Chat.isUserComment(nil) == false, "")
    }
}
