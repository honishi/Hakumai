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

    // swiftlint:disable function_body_length
    func testReplaceComment() {
        var comment = ""
        var expected = ""
        var actual = ""
        let caster = Premium.caster

        // cruise
        comment = "/cruise \"まもなく生放送クルーズが到着します\""
        expected = "⚓️ まもなく生放送クルーズが到着します"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // emotion
        comment = "/emotion ノシ"
        expected = "💬 ノシ"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // gift
        comment = "/gift champagne_2 14560037 \"空気\" 900 \"\" \"シャンパーン\" 1"
        expected = "🎁 空気さんがギフト「シャンパーン(900pt)」を贈りました"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // gift (NULL=名無し)
        comment = "/gift stamp_okaeri NULL \"名無し\" 30 \"\" \"おかえり\""
        expected = "🎁 名無しさんがギフト「おかえり(30pt)」を贈りました"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // info
        comment = "/info 10 「横山緑」が好きな1人が来場しました"
        expected = "ℹ️ 「横山緑」が好きな1人が来場しました"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // nicoad
        comment = "/nicoad {\"totalAdPoint\":15800,\"message\":\"【広告貢献1位】makimakiさんが2100ptニコニ広告しました\",\"version\":\"1\"}"
        expected = "📣 【広告貢献1位】makimakiさんが2100ptニコニ広告しました"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // quote
        comment = "/quote \"「tm2さん」が引用を開始しました\""
        expected = "⛴ 「tm2さん」が引用を開始しました"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // spi
        comment = "/spi \"「【むらまこ】原付バイクでの道路交通法違反【最高速度60km/h】」がリクエストされました\""
        expected = "🎮 「【むらまこ】原付バイクでの道路交通法違反【最高速度60km/h】」がリクエストされました"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // vote
        comment = "/vote start お墓 継ぐ 継がない 自分の代で終わらせる"
        expected = "🙋‍♂️ アンケ start お墓 継ぐ 継がない 自分の代で終わらせる"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")

        // when comment spec changed?
        comment = "/nicoad {\"XXXtotalAdPoint\":15800,\"XXXmessage\":\"【広告貢献1位】makimakiさんが2100ptニコニ広告しました\",\"version\":\"1\"}"
        expected = "📣 {\"XXXtotalAdPoint\":15800,\"XXXmessage\":\"【広告貢献1位】makimakiさんが2100ptニコニ広告しました\",\"version\":\"1\"}"
        actual = comment.slashCommandReplaced(premium: caster)
        XCTAssert(expected == actual, "")
    }
    // swiftlint:enable function_body_length
}
