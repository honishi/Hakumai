//
//  NicoUtilityExtractor.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Ono

// collection of xml extractor

private let kPlaceholderSeatNo = -1

extension NicoUtility {
    // MARK: - General
    func isErrorResponse(_ xmlData: Data) -> (error: Bool, code: String) {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: 0)
        } catch let error1 as NSError {
            error = error1
            logger.error("\(error)")
            xmlDocument = nil
        }
        let rootElement = xmlDocument?.rootElement()
        
        let status = rootElement?.attribute(forName: "status")?.stringValue
        
        if status == "fail" {
            logger.warning("failed to load message server")
            
            var code = ""
            if let codeInResponse = rootElement?.firstStringValueForXPathNode("/getplayerstatus/error/code") {
                logger.warning("error code: \(codeInResponse)")
                code = codeInResponse
            }
            
            return (error: true, code: code)
        }
        
        return (error: false, code: "")
    }
    
    // MARK: - GetPlayerStatus
    func extractLive(_ xmlData: Data) -> Live? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: 0)
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            logger.error("\(error)")
        }
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
    
    func extractUser(_ xmlData: Data) -> User? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: 0)
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            logger.error("\(error)")
        }
        let rootElement = xmlDocument?.rootElement()
        
        let user = User()
        let baseXPath = "/getplayerstatus/user/"
        
        user.userId = rootElement?.firstIntValueForXPathNode(baseXPath + "user_id")
        user.nickname = rootElement?.firstStringValueForXPathNode(baseXPath + "nickname")
        user.isPremium = rootElement?.firstIntValueForXPathNode(baseXPath + "is_premium")
        user.roomLabel = rootElement?.firstStringValueForXPathNode(baseXPath + "room_label")
        user.seatNo = rootElement?.firstIntValueForXPathNode(baseXPath + "room_seetno")

        // fill seat no if extraction fails, espacially for backstage pass case
        if user.seatNo == nil {
            user.seatNo = kPlaceholderSeatNo
        }

        return user
    }
    
    func extractMessageServer(_ xmlData: Data, user: User) -> MessageServer? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: 0)
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            logger.error("\(error)")
        }
        let rootElement = xmlDocument?.rootElement()
        
        let status = rootElement?.attribute(forName: "status")?.stringValue
        
        if status == "fail" {
            logger.warning("failed to load message server")
            
            if let errorCode = rootElement?.firstStringValueForXPathNode("/getplayerstatus/error/code") {
                logger.warning("error code: \(errorCode)")
            }
            
            return nil
        }
        
        let roomPosition = roomPositionByUser(user)
        
        if roomPosition == nil {
            return nil
        }
        
        let baseXPath = "/getplayerstatus/ms/"
        
        let address = rootElement?.firstStringValueForXPathNode(baseXPath + "addr")
        let port = rootElement?.firstIntValueForXPathNode(baseXPath + "port")
        let thread = rootElement?.firstIntValueForXPathNode(baseXPath + "thread")
        // logger.debug("\(address?),\(port),\(thread)")
        
        if address == nil || port == nil || thread == nil {
            return nil
        }
        
        let server = MessageServer(roomPosition: roomPosition!, address: address!, port: port!, thread: thread!)
        
        return server
    }
    
    func roomPositionByUser(_ user: User) -> RoomPosition? {
        // logger.debug("roomLabel:\(roomLabel)")
        
        if user.roomLabel == nil {
            return nil
        }

        if user.isArena == true || user.isBSP == true {
            return RoomPosition(rawValue: 0)
        }
        
        if let roomLabel = user.roomLabel, let standCharacter = extractStandCharacter(roomLabel) {
            logger.debug("extracted standCharacter:\(standCharacter)")
            let raw = (standCharacter - ("A" as Character)) + 1
            return RoomPosition(rawValue: raw)
        }
        
        return nil
    }

    private func extractStandCharacter(_ roomLabel: String) -> Character? {
        let matched = roomLabel.extractRegexpPattern("立ち見(\\w)列")
        
        // using subscript String extension defined above
        return matched?[0]
    }
    
    // MARK: - Community
    func extractUserCommunity(_ htmlData: Data, community: Community) {
        var error: NSError?
        let htmlDocument: ONOXMLDocument!
        do {
            htmlDocument = try ONOXMLDocument.htmlDocument(with: htmlData)
        } catch let error1 as NSError {
            error = error1
            htmlDocument = nil
            logger.error("\(error)")
        }
        let rootElement = htmlDocument?.rootElement
        
        if rootElement == nil {
            logger.error("rootElement is nil")
            return
        }
        
        let xpathTitle = "//*[@id=\"community_name\"]"
        community.title = rootElement?.firstChild(withXPath: xpathTitle)?.stringValue().stringByRemovingPattern("\n")
        
        let xpathLevel = "//*[@id=\"cbox_profile\"]/table/tr/td[1]/table/tr[1]/td[2]/strong[1]"
        community.level = Int(rootElement?.firstChild(withXPath: xpathLevel)?.stringValue() ?? "1")
        
        let xpathThumbnailUrl = "//*[@id=\"cbox_profile\"]/table/tr/td[2]/p/img/@src"
        if let thumbnailUrl = rootElement?.firstChild(withXPath: xpathThumbnailUrl)?.stringValue() {
            community.thumbnailUrl = URL(string: thumbnailUrl)
        }
    }
    
    func extractChannelCommunity(_ htmlData: Data, community: Community) {
        var error: NSError?
        let htmlDocument: ONOXMLDocument!
        do {
            htmlDocument = try ONOXMLDocument.htmlDocument(with: htmlData)
        } catch let error1 as NSError {
            error = error1
            logger.error("\(error)")
            htmlDocument = nil
        }
        let rootElement = htmlDocument?.rootElement
        
        if rootElement == nil {
            logger.error("rootElement is nil")
            return
        }
        
        let xpathTitle = "//*[@id=\"head_cp_breadcrumb\"]/h1/a"
        community.title = rootElement?.firstChild(withXPath: xpathTitle)?.stringValue().stringByRemovingPattern("\n")
        
        let xpathThumbnailUrl = "//*[@id=\"cp_symbol\"]/span/a/img/@data-original"
        if let thumbnailUrl = rootElement?.firstChild(withXPath: xpathThumbnailUrl)?.stringValue() {
            community.thumbnailUrl = URL(string: thumbnailUrl)
        }
    }
    
    // MARK: - Username
    func extractUsername(_ htmlData: Data) -> String? {
        var error: NSError?
        let htmlDocument: ONOXMLDocument!
        do {
            htmlDocument = try ONOXMLDocument.htmlDocument(with: htmlData)
        } catch let error1 as NSError {
            error = error1
            htmlDocument = nil
            logger.error("\(error)")
        }
        let rootElement = htmlDocument?.rootElement
        
        // /html/body/div[3]/div[2]/h2/text() -> other's userpage
        // /html/body/div[4]/div[2]/h2/text() -> my userpage, contains '他のユーザーから見たあなたのプロフィールです。' box
        let username = rootElement?.firstChild(withXPath: "/html/body/*/div[2]/h2")?.stringValue()
        let cleansed = username?.stringByRemovingPattern("(?:さん|)\\s*$")
        
        return cleansed
    }
    
    // MARK: - Heartbeat
    func extractHeartbeat(_ xmlData: Data) -> Heartbeat? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: 0)
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            logger.error("\(error)")
        }
        let rootElement = xmlDocument?.rootElement()
        
        let heartbeat = Heartbeat()
        let baseXPath = "/heartbeat/"
        
        if let status = rootElement?.firstStringValueForXPathNode(baseXPath + "@status") {
            heartbeat.status = Heartbeat.statusFromString(status: status)
        }
        
        if heartbeat.status == Heartbeat.Status.ok {
            heartbeat.watchCount = rootElement?.firstIntValueForXPathNode(baseXPath + "watchCount")
            heartbeat.commentCount = rootElement?.firstIntValueForXPathNode(baseXPath + "commentCount")
            heartbeat.freeSlotNum = rootElement?.firstIntValueForXPathNode(baseXPath + "freeSlotNum")
            heartbeat.isRestrict = rootElement?.firstIntValueForXPathNode(baseXPath + "is_restrict")
            heartbeat.ticket = rootElement?.firstStringValueForXPathNode(baseXPath + "ticket")
            heartbeat.waitTime = rootElement?.firstIntValueForXPathNode(baseXPath + "waitTime")
        }
        else if heartbeat.status == Heartbeat.Status.fail {
            if let errorCode = rootElement?.firstStringValueForXPathNode(baseXPath + "error/code") {
                heartbeat.errorCode = Heartbeat.errorCodeFromString(errorCode: errorCode)
            }
        }
        
        return heartbeat
    }
}
