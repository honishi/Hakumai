//
//  SpeechManagerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/27/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import XCTest
@testable import Hakumai

final class SpeechManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // swiftlint:disable function_body_length
    @available(macOS 10.14, *)
    func testCleanComment() {
        var comment = ""
        var expected = ""
        var actual = ""

        comment = "母親を殴っていた自分が恥ずかしくなりました"
        expected = "母親を殴っていた自分が恥ずかしくなりました"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "w"
        expected = " わら"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "ｗ"
        expected = " わら"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "www"
        expected = " わらわら"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "ｗｗｗ"
        expected = " わらわら"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "こんにちはｗ"
        expected = "こんにちは わら"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "こんにちはｗｗｗ"
        expected = "こんにちは わらわら"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "誰も共感してくれなくて可哀想wwwぶた"
        expected = "誰も共感してくれなくて可哀想 わらわらぶた"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "いよいよ就寝か。。　(ﾟ∀ﾟ)"
        expected = "いよいよ就寝か。。　"
        actual = SpeechManager.shared.cleanComment(from: comment)
        // XCTAssert(expected == actual, "")

        comment = "8888888888888888888888888888888888888888888888888"
        expected = "ぱちぱち"
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "これ見てhttps://example.com/aaa"
        expected = "これ見て URL "
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "これ見てhttps://example.com/aaaこれ"
        expected = "これ見て URL "
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "これ見てhttps://www.youtube.com/watch?v=9Pg2CDCm34w"
        expected = "これ見て URL "
        actual = SpeechManager.shared.cleanComment(from: comment)
        XCTAssert(expected == actual, "")
    }
    // swiftlint:enable function_body_length
}
