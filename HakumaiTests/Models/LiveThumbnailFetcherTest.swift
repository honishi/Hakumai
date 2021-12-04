//
//  LiveThumbnailFetcherTest.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 2021/12/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import XCTest
@testable import Hakumai

class LiveThumbnailFetcherTest: XCTestCase {
    override func setUpWithError() throws {}
    override func tearDownWithError() throws {}

    func testExtractLiveThumbnailUrl() throws {
        let html = "live_page.html".resourceFileToString()
        let fetcher = LiveThumbnailFetcher()

        let result = fetcher.exposedExtractLiveThumbnailUrl(from: html)
        let expect = "https://ssth.dmc.nico/thumbnail/20211204/22/00/nicolive-production-pg34220272517733/nicolive-production-pg34220272517733_800_450.jpg?t=1638627321907"
        XCTAssert(result?.absoluteString == expect)
    }
}
