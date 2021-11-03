//
//  RankingManagerTests.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 2021/11/02.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import XCTest
@testable import Hakumai

class RankingManagerTests: XCTestCase {
    override func setUpWithError() throws {}
    override func tearDownWithError() throws {}

    func testExtractChikuranHtml() throws {
        let manager = RankingManager()
        let html = "chikuran.html".resourceFileToString()

        let result = manager.exposedExtractRankMap(from: html)
        // print(result)
        XCTAssert(!result.isEmpty)
    }
}
