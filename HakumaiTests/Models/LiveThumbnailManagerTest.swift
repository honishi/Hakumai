//
//  LiveThumbnailManagerTest.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 2021/12/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import XCTest
@testable import Hakumai

class LiveThumbnailManagerTest: XCTestCase {
    override func setUpWithError() throws {}
    override func tearDownWithError() throws {}

    func testExtractLiveThumbnailUrl() throws {
        let html = "live_page.html".resourceFileToString()
        let manager = LiveThumbnailManager()

        let result = manager.exposedExtractLiveThumbnailUrl(from: html)
        let expect = "https://ssth.dmc.nico/thumbnail/20211204/22/00/nicolive-production-pg34220272517733/nicolive-production-pg34220272517733_800_450.jpg?t=1638627321907"
        XCTAssert(result?.absoluteString == expect)
    }

    // swiftlint:disable force_unwrapping
    func testConstructLiveThumbnailUrl() throws {
        let manager = LiveThumbnailManager()
        var originalUrl: URL
        var result: URL?
        var expect: String

        originalUrl = URL(string: "https://ssth.dmc.nico/thumbnail/20211205/11/15/nicolive-production-pg21091510649445/nicolive-production-pg21091510649445_800_450.jpg?t=1638678178738")!
        // 2021/12/05 01:02:03
        let date = Date.init(timeIntervalSince1970: 1638633723)
        result = manager.exposedConstructLiveThumbnailUrl(from: originalUrl, for: date)
        expect = "https://ssth.dmc.nico/thumbnail/20211205/11/15/nicolive-production-pg21091510649445/nicolive-production-pg21091510649445_800_450.jpg?t=1638633723000"
        XCTAssert(result?.absoluteString == expect)

        originalUrl = URL(string: "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/defaults/blank.jpg")!
        result = manager.exposedConstructLiveThumbnailUrl(from: originalUrl, for: Date())
        expect = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/defaults/blank.jpg"
        XCTAssert(result?.absoluteString == expect)
    }
    // swiftlint:enable force_unwrapping
}
