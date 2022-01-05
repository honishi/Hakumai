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
        XCTAssert(Chat.toSlashCommane(from: "") == nil, "")
        XCTAssert(Chat.toSlashCommane(from: "nicoad") == nil, "")
        XCTAssert(Chat.toSlashCommane(from: "nicoad ") == nil, "")
        XCTAssert(Chat.toSlashCommane(from: "/nicoad xxx") == .nicoad, "")
        XCTAssert(Chat.toSlashCommane(from: "/gift xxx") == .gift, "")
        XCTAssert(Chat.toSlashCommane(from: "/vote xxx") == .vote, "")
        XCTAssert(Chat.toSlashCommane(from: "/abc xxx") == .unknown, "")
    }
}
