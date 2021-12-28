//
//  DatabaseValueCacherTests.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 2021/12/28.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import XCTest
@testable import Hakumai

class DatabaseValueCacherTests: XCTestCase {
    override func setUpWithError() throws {}
    override func tearDownWithError() throws {}

    func testExample() throws {
        let cacher = DatabaseValueCacher<String>()
        let userId1 = "userId1"
        let communityId1 = "communityId1"
        // let userId2 = "userId2"
        // let communityId2 = "communityId2"

        var actual: DatabaseValueCacher<String>.CacheResult
        var expected: DatabaseValueCacher<String>.CacheResult

        actual = cacher.cachedValue(for: userId1, in: communityId1)
        expected = .notCached
        XCTAssert(actual == expected)

        cacher.update(value: "abc", for: userId1, in: communityId1)
        actual = cacher.cachedValue(for: userId1, in: communityId1)
        expected = .cached("abc")
        XCTAssert(actual == expected)

        cacher.updateValueAsNil(for: userId1, in: communityId1)
        actual = cacher.cachedValue(for: userId1, in: communityId1)
        expected = .cached(nil)
        XCTAssert(actual == expected)
    }
}
