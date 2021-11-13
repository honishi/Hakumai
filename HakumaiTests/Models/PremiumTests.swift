//
//  PremiumTests.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 2021/11/13.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import XCTest
@testable import Hakumai

class PremiumTests: XCTestCase {
    override func setUpWithError() throws {}
    override func tearDownWithError() throws {}

    func testIsSystem() {
        XCTAssert(Premium.ippan.isSystem == false, "")
        XCTAssert(Premium.premium.isSystem == false, "")
        XCTAssert(Premium.system.isSystem == true, "")
    }

    func testIsUser() {
        XCTAssert(Premium.ippan.isUser == true, "")
        XCTAssert(Premium.premium.isUser == true, "")
        XCTAssert(Premium.system.isUser == false, "")
    }
}
