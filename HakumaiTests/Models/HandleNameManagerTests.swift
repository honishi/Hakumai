//
//  HandleNameManagerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
@testable import Hakumai

final class HandleNameManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testExtractHandleName() {
        // full-width at mark
        checkExtractHandleName("わこ＠あいうえお", expected: "あいうえお")
        checkExtractHandleName("＠あいうえお", expected: "あいうえお")

        // normal at mark
        checkExtractHandleName("わこ@あいうえお", expected: "あいうえお")
        checkExtractHandleName("@あいうえお", expected: "あいうえお")

        // has space
        checkExtractHandleName("わこ@ あいうえお", expected: "あいうえお")
        checkExtractHandleName("わこ@あいうえお ", expected: "あいうえお")
        checkExtractHandleName("わこ@ あいうえお ", expected: "あいうえお")
        checkExtractHandleName("わこ@　あいうえお", expected: "あいうえお")
        checkExtractHandleName("わこ@あいうえお　", expected: "あいうえお")
        checkExtractHandleName("わこ@　あいうえお　", expected: "あいうえお")

        // user comment that notifies live remaining minutes
        checkExtractHandleName("＠５", expected: nil)
        checkExtractHandleName("＠5", expected: nil)
        checkExtractHandleName("＠10", expected: nil)
        checkExtractHandleName("＠１０", expected: nil)
        checkExtractHandleName("＠96猫", expected: "96猫")
        checkExtractHandleName("＠９６猫", expected: "９６猫")

        // mail address
        checkExtractHandleName("ご連絡はmail@example.comまで", expected: nil)
    }

    func checkExtractHandleName(_ comment: String, expected: String?) {
        XCTAssert(HandleNameManager.shared.extractHandleName(from: comment) == expected, "")
    }

    func testUpsertThenSelectHandleName() {
        let communityId = "co" + String(Int.random(in: 0...99))
        let userId = String(Int.random(in: 0...99))
        let handleName = "山田"

        HandleNameManager.shared.upsert(handleName: handleName, for: userId, in: communityId)

        let resolved = HandleNameManager.shared.selectHandleName(for: userId, in: communityId)
        XCTAssert(resolved == handleName, "")
    }
}
