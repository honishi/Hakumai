//
//  NicoUtilityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/14/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
@testable import Hakumai

private let kAsyncTimeout: TimeInterval = 3

final class NicoUtilityTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - User Account
    func testUserIcon() {
        var expected: String? = ""
        var actual: String? = ""

        expected = nil
        actual = NicoUtility.shared.userIconUrl(for: "XXX")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/0/2.jpg"
        actual = NicoUtility.shared.userIconUrl(for: "2")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/0/9005.jpg"
        actual = NicoUtility.shared.userIconUrl(for: "9005")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/9/99998.jpg"
        actual = NicoUtility.shared.userIconUrl(for: "99998")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/1/12346.jpg"
        actual = NicoUtility.shared.userIconUrl(for: "12346")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/25/252346.jpg"
        actual = NicoUtility.shared.userIconUrl(for: "252346")?.absoluteString
        XCTAssert(actual == expected)
    }

    // MARK: - Test Utility
    // swiftlint:disable force_unwrapping
    func dataForResource(_ fileName: String) -> Data {
        let bundle = Bundle(for: NicoUtilityTests.self)
        let path = bundle.path(forResource: fileName, ofType: nil)
        let fileHandle = FileHandle(forReadingAtPath: path!)
        let data = fileHandle?.readDataToEndOfFile()
        return data!
    }
    // swiftlint:enable force_unwrapping
}
