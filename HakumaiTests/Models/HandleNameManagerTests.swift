//
//  HandleNameManagerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Cocoa
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

    func testColorHexOmitsOpaqueAlpha() {
        let color = NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)

        XCTAssertEqual(color.hex, "#FF8000")
    }

    func testColorHexIncludesNonOpaqueAlpha() {
        let color = NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.5)

        XCTAssertEqual(color.hex, "#FF800080")
    }

    func testUpsertThenSelectColorPreservesAlpha() {
        let communityId = "co" + UUID().uuidString
        let userId = UUID().uuidString
        let color = NSColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.5)

        HandleNameManager.shared.upsert(color: color, for: userId, in: communityId)

        guard let resolved = HandleNameManager.shared.selectColor(for: userId, in: communityId)?
                .usingColorSpace(.sRGB) else {
            XCTFail("failed to resolve color")
            return
        }
        XCTAssertEqual(resolved.redComponent, color.redComponent, accuracy: 1.0 / 255.0)
        XCTAssertEqual(resolved.greenComponent, color.greenComponent, accuracy: 1.0 / 255.0)
        XCTAssertEqual(resolved.blueComponent, color.blueComponent, accuracy: 1.0 / 255.0)
        XCTAssertEqual(resolved.alphaComponent, color.alphaComponent, accuracy: 1.0 / 255.0)
    }
}
