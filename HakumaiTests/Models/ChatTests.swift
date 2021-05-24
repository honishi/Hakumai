//
//  ChatTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
@testable import Hakumai

final class ChatTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIsRawUserId() {
        XCTAssert(Chat.isRawUserId("123") == true, "")
        XCTAssert(Chat.isRawUserId("123a") == false, "")
        XCTAssert(Chat.isRawUserId(nil) == false, "")
    }

    func testIsUserComment() {
        XCTAssert(Chat.isUserComment(Premium.ippan) == true, "")
        XCTAssert(Chat.isUserComment(Premium.premium) == true, "")
        XCTAssert(Chat.isUserComment(Premium.system) == false, "")
        XCTAssert(Chat.isUserComment(nil) == false, "")
    }

    func testReplaceComment() {
        var comment = ""
        var expected = ""
        var actual = ""
        let caster = Premium.caster

        // cruise
        comment = "/cruise \"まもなく生放送クルーズが到着します\""
        expected = "⚓️ まもなく生放送クルーズが到着します"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // emotion
        comment = "/emotion ノシ"
        expected = "💬 ノシ"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // gift
        comment = "/gift champagne_2 14560037 \"空気\" 900 \"\" \"シャンパーン\" 1"
        expected = "🎁 空気さんがギフト「シャンパーン(900pt)」を贈りました"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // gift (NULL=名無し)
        comment = "/gift stamp_okaeri NULL \"名無し\" 30 \"\" \"おかえり\""
        expected = "🎁 名無しさんがギフト「おかえり(30pt)」を贈りました"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // info
        comment = "/info 10 「横山緑」が好きな1人が来場しました"
        expected = "ℹ️ 「横山緑」が好きな1人が来場しました"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // nicoad
        comment = "/nicoad {\"totalAdPoint\":15800,\"message\":\"【広告貢献1位】makimakiさんが2100ptニコニ広告しました\",\"version\":\"1\"}"
        expected = "📣 【広告貢献1位】makimakiさんが2100ptニコニ広告しました"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // quote
        comment = "/quote \"「tm2さん」が引用を開始しました\""
        expected = "⛴ 「tm2さん」が引用を開始しました"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // spi
        comment = "/spi \"「【むらまこ】原付バイクでの道路交通法違反【最高速度60km/h】」がリクエストされました\""
        expected = "🎮 「【むらまこ】原付バイクでの道路交通法違反【最高速度60km/h】」がリクエストされました"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // vote
        comment = "/vote start お墓 継ぐ 継がない 自分の代で終わらせる"
        expected = "🙋‍♂️ アンケ start お墓 継ぐ 継がない 自分の代で終わらせる"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")

        // when comment spec changed?
        comment = "/nicoad {\"XXXtotalAdPoint\":15800,\"XXXmessage\":\"【広告貢献1位】makimakiさんが2100ptニコニ広告しました\",\"version\":\"1\"}"
        expected = "📣 {\"XXXtotalAdPoint\":15800,\"XXXmessage\":\"【広告貢献1位】makimakiさんが2100ptニコニ広告しました\",\"version\":\"1\"}"
        actual = Chat.replaceSlashCommand(comment: comment, premium: caster)
        XCTAssert(expected == actual, "")
    }
}
