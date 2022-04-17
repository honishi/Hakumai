//
//  ChatTests.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 2022/01/05.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import XCTest
@testable import Hakumai

class ChatTests: XCTestCase {
    override func setUpWithError() throws {}
    override func tearDownWithError() throws {}

    // swiftlint:disable force_unwrapping
    func testToSlashCommand() throws {
        XCTAssert(Chat.toSlashCommand(from: "") == nil, "")
        XCTAssert(Chat.toSlashCommand(from: "nicoad") == nil, "")
        XCTAssert(Chat.toSlashCommand(from: "nicoad ") == nil, "")
        XCTAssert(Chat.toSlashCommand(from: "/nicoad xxx") == .nicoad, "")
        let url = URL(string: "https://secure-dcdn.cdn.nimg.jp/nicoad/res/nage/thumbnail/xxx.png")!
        XCTAssert(Chat.toSlashCommand(from: "/gift xxx ") == .gift(url), "")
        XCTAssert(Chat.toSlashCommand(from: "/vote xxx") == .vote, "")
        XCTAssert(Chat.toSlashCommand(from: "/abc xxx") == .unknown, "")
    }
    // swiftlint:enable force_unwrapping
}
