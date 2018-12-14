//
//  CommonExtensionsTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/17/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class StringExtensionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    // MARK: String
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
