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
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Comment Server Info
    func testExtractCommentServerInfo() {
        let html = dataForResource("live_page.html")
        let extracted = NicoUtility.extractEmbeddedDataPropertiesFromLivePage(html: html)
        XCTAssert(extracted?.site.relive.webSocketUrl == "wss://a.live2.nicovideo.jp/unama/wsapi/v2/watch/12345?audience_token=12345_12345_12345_abcde")
    }

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
}
