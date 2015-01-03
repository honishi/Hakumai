//
//  CookieUtilityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/16/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class CookieUtilityTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: cookie utility
    func testChromeCookie() {
        let cookie = CookieUtility.cookie(CookieUtility.BrowserType.Chrome)
        XCTAssert(0 < cookie?.utf16Count, "")
    }
}
