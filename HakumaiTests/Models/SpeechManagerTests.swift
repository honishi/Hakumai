//
//  SpeechManagerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/27/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import XCTest

class SpeechManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testCleanComment() {
        var comment = ""
        var expected = ""
        var actual = ""

        comment = "母親を殴っていた自分が恥ずかしくなりました"
        expected = "母親を殴っていた自分が恥ずかしくなりました"
        actual = SpeechManager.sharedManager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "/press show yellow 母親を殴っていた自分が恥ずかしくなりました @ ラピス"
        expected = "母親を殴っていた自分が恥ずかしくなりました @ ラピス"
        actual = SpeechManager.sharedManager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")
    }
}
