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
    func testPreCheckComment() {
        let manager = SpeechManager()
        var comment = ""
        var result: SpeechManager.CommentPreCheckResult

        comment = "無職なのになんでカフェいくの？？？？？？？"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        // length: 71
        comment = "初見です。骨皮筋bsゲス出っ歯人中ロングお未婚お下劣目尻ほうれい線口元シワシワ髪質ゴワゴワ体型貧相性格底辺人間力マイナスのむらマコさんわこつ。"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        // length: 110
        comment = "初見です。骨皮筋bsゲス出っ歯人中ロングお未婚お下劣目尻ほうれい線口元シワシワ髪質ゴワゴワ体型貧相性格底辺人間力マイナスのむらマコさんわこつ。初見です。骨皮筋bsゲス出っ歯人中ロングお未婚お下劣目尻ほうれい線口元シワシワ"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.long))

        comment = "👄👈🏻💗💗💗"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = """
            🟥🟧🟨🟩🟦🟪🟥🟧🟨🟩🟦🟪🟥🟧🟨🟩
            🟥🟧🟨🟩🟦🟪(⌒,_ゝ⌒)🟩🟦🟪🟥🟧🟨🟩
            🟥🟧🟨🟩🟦🟪もこレインボー🟪🟥🟧🟨🟩
            🟥🟧🟨🟩🟦🟪🟥🟧🟨🟩🟦🟪🟥🟧🟨🟩
            """
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyEmoji))

        comment = """
            .　　 ヾヽ
            .　 (o⌒,_ゝ⌒) ネオもこバード
            　　ﾉ\"\"\"\" )　 )
            　 彡ノ,,,,ノ
            ―〃-〃―――
            　　ﾚ,,/
            """
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyLines))

        comment = "粨粨粨粨粨粨粨粨粨粨粨粨粨粨粨粨粨粨"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manySameKanji))

        comment = "鹅鹅鹅鹅鹅鹅鹅鹅鹅鹅鹅鹅鹅鹅鹅鹅"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manySameKanji))

        comment = "えええええええええええええええええええええええええええええええええええｗｗｗｗｗｗｗｗｗｗｗｗ"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "ｗｗｗｗｗｗｗｗｗｗｗｗ"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "えええええええええええええええええええええええええええええええええええ"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "12345678"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "123456789"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyNumber))

        comment = "１２３４５６７８"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "１２３４５６７８９"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyNumber))

        comment = "44444444"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "444444444"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyNumber))

        comment = "４４４４４４４４"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "４４４４４４４４４"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyNumber))

        comment = "これは４４４４４４４４円です"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .accept)

        comment = "これは４４４４４４４４４円です"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyNumber))

        comment = "４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４"
        result = manager.preCheckComment(comment)
        XCTAssert(result == .reject(.manyNumber))
    }
    // swiftlint:enable function_body_length

    // swiftlint:disable function_body_length
    @available(macOS 10.14, *)
    func testCleanComment() {
        let manager = SpeechManager()
        var comment = ""
        var expected = ""
        var actual = ""

        comment = "母親を殴っていた自分が恥ずかしくなりました"
        expected = "母親を殴っていた自分が恥ずかしくなりました"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "w"
        expected = " わら"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "ｗ"
        expected = " わら"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "www"
        expected = " わらわら"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "ｗｗｗ"
        expected = " わらわら"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "こんにちはｗ"
        expected = "こんにちは わら"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "こんにちはｗｗｗ"
        expected = "こんにちは わらわら"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "誰も共感してくれなくて可哀想wwwぶた"
        expected = "誰も共感してくれなくて可哀想 わらわらぶた"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "いよいよ就寝か。。　(ﾟ∀ﾟ)"
        expected = "いよいよ就寝か。。　"
        actual = manager.cleanComment(from: comment)
        // XCTAssert(expected == actual, "")

        comment = "8888888888888888888888888888888888888888888888888"
        expected = "ぱちぱち"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "これ見てhttps://example.com/aaa"
        expected = "これ見て URL "
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "これ見てhttps://example.com/aaaこれ"
        expected = "これ見て URL "
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "これ見てhttps://www.youtube.com/watch?v=9Pg2CDCm34w"
        expected = "これ見て URL "
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "ニコニコ生放送"
        expected = "ニコニコ生放送"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "私はニコニコ生放送を見てる"
        expected = "私はニコニコ生放送を見てる"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "ニコ生"
        expected = "ニコなま"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "私はニコ生を見てる"
        expected = "私はニコなまを見てる"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")

        comment = "初見"
        expected = "しょけん"
        actual = manager.cleanComment(from: comment)
        XCTAssert(expected == actual, "")
    }
    // swiftlint:enable function_body_length
}
