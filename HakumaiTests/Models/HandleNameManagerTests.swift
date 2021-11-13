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

    func testInsertOrReplaceThenSelectHandleName() {
        let communityId = "co" + String(arc4random() % 100)
        let userId = String(arc4random() % 100)
        let handleName = "山田"

        HandleNameManager.shared.insertOrReplaceHandleName(communityId: communityId, userId: userId, anonymous: false, handleName: handleName)

        let resolved = HandleNameManager.shared.selectHandleName(communityId: communityId, userId: userId)
        XCTAssert(resolved == handleName, "")
    }
}
