//
//  HandleNameManagerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class HandleNameManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExtractHandleName() {
        // full-width at mark
        self.checkExtractHandleName("わこ＠あいうえお", expected: "あいうえお")
        self.checkExtractHandleName("＠あいうえお", expected: "あいうえお")

        // normal at mark
        self.checkExtractHandleName("わこ@あいうえお", expected: "あいうえお")
        self.checkExtractHandleName("@あいうえお", expected: "あいうえお")
        
        // has space
        self.checkExtractHandleName("わこ@ あいうえお", expected: "あいうえお")
        self.checkExtractHandleName("わこ@あいうえお ", expected: "あいうえお")
        self.checkExtractHandleName("わこ@ あいうえお ", expected: "あいうえお")
        self.checkExtractHandleName("わこ@　あいうえお", expected: "あいうえお")
        self.checkExtractHandleName("わこ@あいうえお　", expected: "あいうえお")
        self.checkExtractHandleName("わこ@　あいうえお　", expected: "あいうえお")
        
        // user comment that notifies live remaining minutes
        self.checkExtractHandleName("＠５", expected: nil)
        self.checkExtractHandleName("＠5", expected: nil)
        self.checkExtractHandleName("＠10", expected: nil)
        self.checkExtractHandleName("＠１０", expected: nil)
        self.checkExtractHandleName("＠96猫", expected: "96猫")
        self.checkExtractHandleName("＠９６猫", expected: "９６猫")
        
        // mail address
        self.checkExtractHandleName("ご連絡はmail@example.comまで", expected: nil)
    }
    
    func checkExtractHandleName(comment: String, expected: String?) {
        XCTAssert(HandleNameManager.sharedManager.extractHandleNameFromComment(comment) == expected, "")
    }
    
    func testInsertOrReplaceThenSelectHandleName() {
        let communityId = "co" + String(arc4random() % 100)
        let userId = String(arc4random() % 100)
        let handleName = "山田"
        
        HandleNameManager.sharedManager.insertOrReplaceHandleNameWithCommunityId(communityId, userId: userId, anonymous: false, handleName: handleName)
        
        let resolved = HandleNameManager.sharedManager.selectHandleNameWithCommunityId(communityId, userId: userId)
        XCTAssert(resolved == handleName, "")
    }
}