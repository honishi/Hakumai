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

    func testToSlashCommand() throws {
        XCTAssert(Chat.toSlashCommand(from: "") == nil, "")
        XCTAssert(Chat.toSlashCommand(from: "nicoad") == nil, "")
        XCTAssert(Chat.toSlashCommand(from: "nicoad ") == nil, "")
        XCTAssert(Chat.toSlashCommand(from: "/nicoad xxx") == .nicoad, "")
        XCTAssert(Chat.toSlashCommand(from: "/gift xxx") == .gift, "")
        XCTAssert(Chat.toSlashCommand(from: "/vote xxx") == .vote, "")
        XCTAssert(Chat.toSlashCommand(from: "/abc xxx") == .unknown, "")
    }
}
