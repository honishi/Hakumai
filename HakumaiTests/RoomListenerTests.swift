//
//  RoomListenerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/16/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

class RoomListenerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testParseChat() {
        let listener = RoomListener(delegate: nil, server: nil)
        var chat: String
        var parsed: [Chat]?
        
        chat = "<chat thread=\"1394262335\" no=\"5978\" vpos=\"78500\" date=\"1416127205\" date_usec=\"581876\" "
        chat += "mail=\"184\" user_id=\"HSZnsQy73fvuRsoFo1C4N3-Ixyw\" premium=\"3\" anonymity=\"1\">/hb ifseetno 152</chat>"
        parsed = listener.parseChat(chat)
        XCTAssert(parsed?.count == 1, "")
        
        chat += " <chat thread=\"1394262335\" no=\"5979\" vpos=\"78500\" date=\"1416127205\" date_usec=\"581877\" "
        chat += "mail=\"184\" user_id=\"fPmerRLMNnVGNq4MpXwBjqF6w7I\" premium=\"3\" anonymity=\"1\">/hb ifseetno 173</chat>                                                                                                                                  "
        parsed = listener.parseChat(chat)
        XCTAssert(parsed?.count == 2, "")
    }
}
