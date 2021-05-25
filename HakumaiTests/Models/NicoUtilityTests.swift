//
//  NicoUtilityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/14/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
@testable import Hakumai

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

    // MARK: - User Account
    func testUserIcon() {
        var expected = ""
        var actual: String? = ""

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/9/99998.jpg"
        actual = NicoUtility.shared.userIconUrl(for: "99998")?.absoluteString
        XCTAssert(actual == expected)
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
