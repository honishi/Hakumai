//
//  MenuDelegateTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/5/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class MenuDelegateTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK:
    func testUrlStringInComment() {
        let menuDelegate = MenuDelegate()
        let chat = Chat()
        
        chat.comment = "aaa"
        XCTAssert(menuDelegate.urlStringInComment(chat) == nil, "")
        
        chat.comment = "aaa http://example.com aaa"
        XCTAssert(menuDelegate.urlStringInComment(chat) == "http://example.com", "")
    }
}
