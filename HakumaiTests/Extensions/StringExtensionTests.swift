//
//  CommonExtensionsTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/17/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
@testable import Hakumai

final class StringExtensionTests: XCTestCase {
    override func setUp() {}
    override func tearDown() {}
}

// MARK: String
extension StringExtensionTests {
    func testIsRawUserId() {
        XCTAssert("123".isRawUserId == true, "")
        XCTAssert("123a".isRawUserId == false, "")
    }

    func testExtractRegexp() {
        var pattern: String
        var extracted: String?

        pattern = "http:\\/\\/live\\.nicovideo\\.jp\\/watch\\/lv(\\d{5,}).*"
        extracted = "http://live.nicovideo.jp/watch/lv200433812?ref=zero_mynicorepo".extractRegexp(pattern: pattern)
        XCTAssert(extracted == "200433812", "")

        /*
         pattern = "(http:\\/\\/live\\.nicovideo\\.jp\\/watch\\/)?(lv)?(\\d+).*"
         extracted = "http://live.nicovideo.jp/watch/lv200433812?ref=zero_mynicorepo".extractRegexp(pattern: pattern, index: 0)
         XCTAssert(extracted == "200433812", "")
         */
    }

    func testHasRegexp() {
        XCTAssert("abc".hasRegexp(pattern: "b") == true, "")
        XCTAssert("abc".hasRegexp(pattern: "1") == false, "")

        // half-width character with (han)daku-on case. http://stackoverflow.com/a/27192734
        XCTAssert("ﾊﾃﾞｗ".hasRegexp(pattern: "ｗ") == true, "")
    }

    func testStringByRemovingRegexp() {
        var removed: String

        removed = "abcd".stringByRemovingRegexp(pattern: "bc")
        XCTAssert(removed == "ad", "")

        removed = "abcdabcd".stringByRemovingRegexp(pattern: "bc")
        XCTAssert(removed == "adad", "")

        removed = "abc\n".stringByRemovingRegexp(pattern: "\n")
        XCTAssert(removed == "abc", "")
    }
}

extension StringExtensionTests {
    func testExtractLiveNumber() {
        var extracted: String?
        let expected = "lv200433812"

        extracted = "http://live.nicovideo.jp/watch/lv200433812?ref=zero_mynicorepo".extractLiveProgramId()
        XCTAssert(extracted == expected, "")

        extracted = "http://live.nicovideo.jp/watch/lv200433812".extractLiveProgramId()
        XCTAssert(extracted == expected, "")

        extracted = "lv200433812".extractLiveProgramId()
        XCTAssert(extracted == expected, "")
    }

    func testUrlStringInComment() {
        var comment = ""

        comment = "aaa"
        XCTAssert(comment.extractUrlString() == nil, "")

        comment = "aaa http://example.com aaa"
        XCTAssert(comment.extractUrlString() == "http://example.com", "")
    }

    func testIsValidHexString() {
        XCTAssert("".isValidHexString == false, "")
        XCTAssert("123".isValidHexString == false, "")
        XCTAssert("#000000".isValidHexString == true, "")
        XCTAssert("#123456".isValidHexString == true, "")
        XCTAssert("#abcdef".isValidHexString == true, "")
        XCTAssert("#ABCDEF".isValidHexString == true, "")
        XCTAssert("#789abc".isValidHexString == true, "")
        XCTAssert("#789ABC".isValidHexString == true, "")
        XCTAssert("#ffffff".isValidHexString == true, "")
        XCTAssert("#FFFFFF".isValidHexString == true, "")
        XCTAssert("#000".isValidHexString == false, "")
        XCTAssert("#fff".isValidHexString == false, "")
        XCTAssert("#FFF".isValidHexString == false, "")
        XCTAssert("#1234567".isValidHexString == false, "")
        XCTAssert("#fffffff".isValidHexString == false, "")
        XCTAssert("#FFFFFFF".isValidHexString == false, "")
    }
}
