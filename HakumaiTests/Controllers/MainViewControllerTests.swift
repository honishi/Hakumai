//
//  MainViewControllerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/17/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class MainViewControllerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: String
    func testExtractLiveNumber() {
        var extracted: Int?
        let expected = 200433812
        
        extracted = MainViewController.extractLiveNumber("http://live.nicovideo.jp/watch/lv200433812?ref=zero_mynicorepo")
        XCTAssert(extracted == expected, "")
        
        extracted = MainViewController.extractLiveNumber("http://live.nicovideo.jp/watch/lv200433812")
        XCTAssert(extracted == expected, "")
        
        extracted = MainViewController.extractLiveNumber("lv200433812")
        XCTAssert(extracted == expected, "")
        
        extracted = MainViewController.extractLiveNumber("200433812")
        XCTAssert(extracted == expected, "")
    }
}
