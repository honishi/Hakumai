//
//  CommonExtensionsTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/17/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class CommonExtensionsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: String
    func testExtractRegexpPattern() {
        var pattern: String
        var extracted: String?
        
        pattern = "http:\\/\\/live\\.nicovideo\\.jp\\/watch\\/lv(\\d{5,}).*"
        extracted = "http://live.nicovideo.jp/watch/lv200433812?ref=zero_mynicorepo".extractRegexpPattern(pattern)
        XCTAssert(extracted == "200433812", "")
        
        /*
        pattern = "(http:\\/\\/live\\.nicovideo\\.jp\\/watch\\/)?(lv)?(\\d+).*"
        extracted = "http://live.nicovideo.jp/watch/lv200433812?ref=zero_mynicorepo".extractRegexpPattern(pattern, index: 0)
        XCTAssert(extracted == "200433812", "")
         */
    }
}
