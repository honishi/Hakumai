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

    func testStreamByRemovingNull() {
        let listener = RoomListener(delegate: nil, server: nil)
        
        XCTAssert(listener.streamByRemovingNull("aaa\0") == "aaa", "")
        XCTAssert(listener.streamByRemovingNull("aaa\nbbb\0") == "aaa\nbbb", "")
        XCTAssert(listener.streamByRemovingNull("aaa\0bbb\0") == "aaabbb", "")
        XCTAssert(listener.streamByRemovingNull("aaa") == "aaa", "")
    }
    
    func testHasValidBracket() {
        let listener = RoomListener(delegate: nil, server: nil)
        
        XCTAssert(listener.hasValidOpenBracket("<aaa") == true, "")
        XCTAssert(listener.hasValidOpenBracket("aaa") == false, "")
        
        XCTAssert(listener.hasValidCloseBracket("aaa>") == true, "")
        XCTAssert(listener.hasValidCloseBracket("aaa") == false, "")
    }
    
    // 1. <thread resultcode="0" thread="1394699813" ticket="0x2e8e4000" revision="1" server_time="1416296072"/>
    func testParseThreadElement() {
        let listener = RoomListener(delegate: nil, server: nil)
        var thread: String
        var parsed: [Thread]
        
        thread = "<thread resultcode=\"0\" thread=\"1394699813\" ticket=\"0x2e8e4000\" revision=\"1\" server_time=\"1416296072\"/>"
        parsed = listener.parseThreadElement(self.xmlRootElementFromXMLString(thread))
        XCTAssert(parsed.count == 1, "")
    }
    
    // 1. raw id, non-premium, non-scored
    // <chat thread="1394672025" no="22" vpos="28382" date="1416276381" date_usec="870596" user_id="24809412" locale="ja-jp">xxx</chat>
    // 2. 184, premium, scored
    // <chat thread="1394672025" no="23" vpos="28472" date="1416276382" date_usec="236303" mail="184" user_id="cKaHteGaeQDDjyaKrBj-eGqJRz8" premium="1" anonymity="1" locale="ja-jp" score="-5253">xxx</chat>
    func testParseChatElement() {
        let listener = RoomListener(delegate: nil, server: nil)
        var chat: String
        var parsed: [Chat]
        
        chat = "<chat thread=\"1394262335\" no=\"5978\" vpos=\"78500\" date=\"1416127205\" date_usec=\"581876\" "
        chat += "mail=\"184\" user_id=\"HSZnsQy73fvuRsoFo1C4N3-Ixyw\" premium=\"3\" anonymity=\"1\">/hb ifseetno 152</chat>"
        parsed = listener.parseChatElement(self.xmlRootElementFromXMLString(chat))
        XCTAssert(parsed.count == 1, "")
        
        chat += chat
        parsed = listener.parseChatElement(self.xmlRootElementFromXMLString(chat))
        XCTAssert(parsed.count == 2, "")
    }

    func xmlRootElementFromXMLString(xmlString: String) -> NSXMLElement {
        let wrapped = "<items>" + xmlString + "</items>"

        var err: NSError?
        let xmlDocument: NSXMLDocument?
        do {
            xmlDocument = try NSXMLDocument(XMLString: wrapped, options: Int(NSXMLDocumentTidyXML))
        } catch let error as NSError {
            err = error
            xmlDocument = nil
        }
        let rootElement = xmlDocument!.rootElement()

        return rootElement!
    }
}
