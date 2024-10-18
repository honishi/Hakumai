//
//  ChatMessageTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
@testable import Hakumai

final class ChatMessageTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testRemoveHtmlTags() {
        var comment = ""
        var expected = ""
        var actual = ""
        let caster = Premium.caster

        comment = "https://example.com/watch/<u><font color=\"xxx\"><a href=\"xxx\">xxx</a></font></u>?abc"
        expected = "https://example.com/watch/xxx?abc"
        actual = comment.htmlTagRemoved(premium: caster)
        XCTAssert(expected == actual, "")

        comment = "<aaa>bbb</aaa>"
        expected = "<aaa>bbb</aaa>"
        actual = comment.htmlTagRemoved(premium: caster)
        XCTAssert(expected == actual, "")
    }
}
