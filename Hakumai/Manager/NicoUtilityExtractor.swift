//
//  NicoUtilityExtractor.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// collection of xml extractor

extension NicoUtility {
    // MARK: - General
    func isErrorResponse(xmlData: NSData) -> Bool {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let status = rootElement?.attributeForName("status")?.stringValue
        
        if status == "fail" {
            log.warning("failed to load message server")
            
            if let errorCode = rootElement?.firstStringValueForXPathNode("/getplayerstatus/error/code") {
                log.warning("error code: \(errorCode)")
            }
            
            return true
        }
        
        return false
    }
    
    // MARK: - GetPlayerStatus
    func extractLive(xmlData: NSData) -> Live? {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let live = Live()
        let baseXPath = "/getplayerstatus/stream/"
        
        live.liveId = rootElement?.firstStringValueForXPathNode(baseXPath + "id")
        live.title = rootElement?.firstStringValueForXPathNode(baseXPath + "title")
        live.community.community = rootElement?.firstStringValueForXPathNode(baseXPath + "default_community")
        live.baseTime = rootElement?.firstIntValueForXPathNode(baseXPath + "base_time")?.toDateAsTimeIntervalSince1970()
        live.openTime = rootElement?.firstIntValueForXPathNode(baseXPath + "open_time")?.toDateAsTimeIntervalSince1970()
        live.startTime = rootElement?.firstIntValueForXPathNode(baseXPath + "start_time")?.toDateAsTimeIntervalSince1970()
        
        return live
    }
    
    func extractUser(xmlData: NSData) -> User? {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let user = User()
        let baseXPath = "/getplayerstatus/user/"
        
        user.userId = rootElement?.firstIntValueForXPathNode(baseXPath + "user_id")
        user.nickname = rootElement?.firstStringValueForXPathNode(baseXPath + "nickname")
        user.isPremium = rootElement?.firstIntValueForXPathNode(baseXPath + "is_premium")
        user.roomLabel = rootElement?.firstStringValueForXPathNode(baseXPath + "room_label")
        user.seatNo = rootElement?.firstIntValueForXPathNode(baseXPath + "room_seetno")
        
        return user
    }
    
    func extractMessageServer(xmlData: NSData, user: User) -> MessageServer? {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let status = rootElement?.attributeForName("status")?.stringValue
        
        if status == "fail" {
            log.warning("failed to load message server")
            
            if let errorCode = rootElement?.firstStringValueForXPathNode("/getplayerstatus/error/code") {
                log.warning("error code: \(errorCode)")
            }
            
            return nil
        }
        
        if user.roomLabel == nil {
            return nil
        }
        
        let roomPosition = self.roomPositionByRoomLabel(user.roomLabel!)
        
        if roomPosition == nil {
            return nil
        }
        
        let baseXPath = "/getplayerstatus/ms/"
        
        let address = rootElement?.firstStringValueForXPathNode(baseXPath + "addr")
        let port = rootElement?.firstIntValueForXPathNode(baseXPath + "port")
        let thread = rootElement?.firstIntValueForXPathNode(baseXPath + "thread")
        // log.debug("\(address?),\(port),\(thread)")
        
        if address == nil || port == nil || thread == nil {
            return nil
        }
        
        let server = MessageServer(roomPosition: roomPosition!, address: address!, port: port!, thread: thread!)
        
        return server
    }
    
    func roomPositionByRoomLabel(roomLabel: String) -> RoomPosition? {
        // log.debug("roomLabel:\(roomLabel)")
        
        if self.isArena(roomLabel) == true {
            return RoomPosition(rawValue: 0)
        }
        
        if let standCharacter = self.extractStandCharacter(roomLabel) {
            log.debug("extracted standCharacter:\(standCharacter)")
            let raw = (standCharacter - ("A" as Character)) + 1
            return RoomPosition(rawValue: raw)
        }
        
        return nil
    }
    
    private func isArena(roomLabel: String) -> Bool {
        let regexp = NSRegularExpression(pattern: "co\\d+", options: nil, error: nil)!
        let matched = regexp.firstMatchInString(roomLabel, options: nil, range: NSMakeRange(0, roomLabel.utf16Count))
        
        return matched != nil ? true : false
    }
    
    private func extractStandCharacter(roomLabel: String) -> Character? {
        let matched = roomLabel.extractRegexpPattern("立ち見(\\w)列")
        
        // using subscript String extension defined above
        return matched?[0]
    }
    
    // MARK: - Community
    func extractCommunity(xmlData: NSData, community: Community) {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: Int(NSXMLDocumentTidyHTML), error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        if rootElement == nil {
            log.error("rootElement is nil")
            return
        }
        
        let xpathTitle = "//*[@id=\"community_name\"]"
        community.title = rootElement?.firstStringValueForXPathNode(xpathTitle)?.stringByRemovingPattern("\n")
        
        let xpathLevel = "//*[@id=\"cbox_profile\"]/table/tr/td[1]/table/tr[1]/td[2]/strong[1]"
        community.level = rootElement?.firstIntValueForXPathNode(xpathLevel)
        
        let xpathThumbnailUrl = "//*[@id=\"cbox_profile\"]/table/tr/td[2]/p/img/@src"
        if let thumbnailUrl = rootElement?.firstStringValueForXPathNode(xpathThumbnailUrl) {
            community.thumbnailUrl = NSURL(string: thumbnailUrl)
        }
    }
    
    // MARK: - Username
    func extractUsername(xmlData: NSData) -> String? {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: Int(NSXMLDocumentTidyHTML), error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        // /html/body/div[3]/div[2]/h2/text() -> other's userpage
        // /html/body/div[4]/div[2]/h2/text() -> my userpage, contains '他のユーザーから見たあなたのプロフィールです。' box
        let username = rootElement?.firstStringValueForXPathNode("/html/body/*/div[2]/h2")
        let cleansed = username?.stringByRemovingPattern("(?:さん|)\n$")
        
        return cleansed
    }
    
    func isRawUserId(userId: String) -> Bool {
        let regexp = NSRegularExpression(pattern: "^\\d+$", options: nil, error: nil)!
        let matched = regexp.firstMatchInString(userId, options: nil, range: NSMakeRange(0, userId.utf16Count))
        
        return matched != nil ? true : false
    }
    
    // MARK: - Heartbeat
    func extractHeartbeat(xmlData: NSData) -> Heartbeat? {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let heartbeat = Heartbeat()
        let baseXPath = "/heartbeat/"
        
        if let status = rootElement?.firstStringValueForXPathNode(baseXPath + "@status") {
            heartbeat.status = Heartbeat.statusFromString(status: status)
        }
        
        if heartbeat.status == Heartbeat.Status.Ok {
            heartbeat.watchCount = rootElement?.firstIntValueForXPathNode(baseXPath + "watchCount")
            heartbeat.commentCount = rootElement?.firstIntValueForXPathNode(baseXPath + "commentCount")
            heartbeat.freeSlotNum = rootElement?.firstIntValueForXPathNode(baseXPath + "freeSlotNum")
            heartbeat.isRestrict = rootElement?.firstIntValueForXPathNode(baseXPath + "is_restrict")
            heartbeat.ticket = rootElement?.firstStringValueForXPathNode(baseXPath + "ticket")
            heartbeat.waitTime = rootElement?.firstIntValueForXPathNode(baseXPath + "waitTime")
        }
        else if heartbeat.status == Heartbeat.Status.Fail {
            if let errorCode = rootElement?.firstStringValueForXPathNode(baseXPath + "error/code") {
                heartbeat.errorCode = Heartbeat.errorCodeFromString(errorCode: errorCode)
            }
        }
        
        return heartbeat
    }
}