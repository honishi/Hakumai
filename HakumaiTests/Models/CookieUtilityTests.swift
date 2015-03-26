//
//  CookieUtilityTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/16/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

private let kAsyncTimeout: NSTimeInterval = 3

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
    /*
    func testLoginCookie() {
        var asyncExpectation: XCTestExpectation

        // test 1
        asyncExpectation = self.expectationWithDescription("asyncExpectation")
        
        let mailAddress = "test1234@example.com"
        let password = "password"
        
        CookieUtility.requestLoginCookieWithMailAddress(mailAddress, password: password) { (userSessionCookie) -> Void in
            XCTAssert(userSessionCookie != nil, "")
            asyncExpectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(kAsyncTimeout, handler: nil)
        
        // test 2
        // ...
    }
     */
    
    func testChromeCookie() {
        let userSessionCookie = CookieUtility.requestBrowserCookieWithBrowserType(.Chrome)
        XCTAssert(0 < count(userSessionCookie!.utf16), "")
    }
}
