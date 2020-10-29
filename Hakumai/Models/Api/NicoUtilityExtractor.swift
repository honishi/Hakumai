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
    func isErrorResponse(xmlData: Data) -> (error: Bool, code: String) {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: convertToXMLNodeOptions(0))
        } catch let error1 as NSError {
            error = error1
            log.error("\(error?.debugDescription ?? "")")
            xmlDocument = nil
        }
        let rootElement = xmlDocument?.rootElement()

        let status = rootElement?.attribute(forName: "status")?.stringValue

        if status == "fail" {
            log.warning("failed to load message server")

            var code = ""
            if let codeInResponse = rootElement?.firstStringValue(forXPath: "/getplayerstatus/error/code") {
                log.warning("error code: \(codeInResponse)")
                code = codeInResponse
            }

            return (error: true, code: code)
        }

        return (error: false, code: "")
    }

    // MARK: - GetPlayerStatus
    func extractLive(fromXmlData xmlData: Data) -> Live? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: convertToXMLNodeOptions(0))
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            log.error("\(error?.debugDescription ?? "")")
        }
        let rootElement = xmlDocument?.rootElement()

        let live = Live()
        let baseXPath = "/getplayerstatus/stream/"

        live.liveId = rootElement?.firstStringValue(forXPath: baseXPath + "id")
        live.title = rootElement?.firstStringValue(forXPath: baseXPath + "title")
        live.community.community = rootElement?.firstStringValue(forXPath: baseXPath + "default_community")
        live.baseTime = rootElement?.firstIntValue(forXPath: baseXPath + "base_time")?.toDateAsTimeIntervalSince1970()
        live.openTime = rootElement?.firstIntValue(forXPath: baseXPath + "open_time")?.toDateAsTimeIntervalSince1970()
        live.startTime = rootElement?.firstIntValue(forXPath: baseXPath + "start_time")?.toDateAsTimeIntervalSince1970()

        return live
    }

    func extractUser(fromXmlData xmlData: Data) -> User? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: convertToXMLNodeOptions(0))
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            log.error("\(error?.debugDescription ?? "")")
        }
        let rootElement = xmlDocument?.rootElement()

        let user = User()
        let baseXPath = "/getplayerstatus/user/"

        user.userId = rootElement?.firstIntValue(forXPath: baseXPath + "user_id")
        user.nickname = rootElement?.firstStringValue(forXPath: baseXPath + "nickname")
        user.isPremium = rootElement?.firstIntValue(forXPath: baseXPath + "is_premium")
        user.roomLabel = rootElement?.firstStringValue(forXPath: baseXPath + "room_label")
        user.seatNo = rootElement?.firstIntValue(forXPath: baseXPath + "room_seetno")

        // fill seat no if extraction fails, espacially for backstage pass case
        if user.seatNo == nil {
            user.seatNo = kPlaceholderSeatNo
        }

        return user
    }

    func extractMessageServer(fromXmlData xmlData: Data, user: User) -> MessageServer? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: convertToXMLNodeOptions(0))
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            log.error("\(error?.debugDescription ?? "")")
        }
        let rootElement = xmlDocument?.rootElement()
        let status = rootElement?.attribute(forName: "status")?.stringValue

        if status == "fail" {
            log.warning("failed to load message server")
            if let errorCode = rootElement?.firstStringValue(forXPath: "/getplayerstatus/error/code") {
                log.warning("error code: \(errorCode)")
            }
            return nil
        }

        guard let roomPosition = self.roomPosition(byUser: user) else { return nil }

        let baseXPath = "/getplayerstatus/ms/"
        guard let address = rootElement?.firstStringValue(forXPath: baseXPath + "addr"),
              let port = rootElement?.firstIntValue(forXPath: baseXPath + "port"),
              let thread = rootElement?.firstIntValue(forXPath: baseXPath + "thread") else { return nil }
        // log.debug("\(address?),\(port),\(thread)")

        return MessageServer(roomPosition: roomPosition, address: address, port: port, thread: thread)
    }

    func roomPosition(byUser user: User) -> RoomPosition? {
        // log.debug("roomLabel:\(roomLabel)")
        guard let roomLabel = user.roomLabel else { return nil }

        if user.isArena == true || user.isBSP == true {
            return RoomPosition(rawValue: 0)
        }

        guard let standCharacter = extractStandCharacter(roomLabel) else { return nil }

        log.debug("extracted standCharacter:\(standCharacter)")
        let raw = (standCharacter - ("1" as Character)) + 1
        return RoomPosition(rawValue: raw)
    }

    private func extractStandCharacter(_ roomLabel: String) -> Character? {
        let matched = roomLabel.extractRegexp(pattern: "^立ち見(\\d+)$")

        // using subscript String extension defined above
        return matched?[0]
    }

    // MARK: - Community
    func extractUserCommunity(fromHtmlData htmlData: Data, community: Community) {
        var error: NSError?
        let htmlDocument: ONOXMLDocument!
        do {
            htmlDocument = try ONOXMLDocument.htmlDocument(with: htmlData)
        } catch let error1 as NSError {
            error = error1
            htmlDocument = nil
            log.error("\(error?.debugDescription ?? "")")
        }
        let rootElement = htmlDocument?.rootElement

        if rootElement == nil {
            log.error("rootElement is nil")
            return
        }

        let xpathTitle = "//*[@class=\"communityData\"]/*[@class=\"title\"]"
        community.title = rootElement?.firstChild(withXPath: xpathTitle)?.stringValue().stringByRemovingRegexp(pattern: "[\t\n]")

        let xpathLevel = "//*[@class=\"communityScale\"]/*[@class=\"content\"]"
        community.level = Int(rootElement?.firstChild(withXPath: xpathLevel)?.stringValue() ?? "1")

        let xpathThumbnailUrl = "//*[@class=\"communityThumbnail\"]/*/img/@src"
        if let thumbnailUrl = rootElement?.firstChild(withXPath: xpathThumbnailUrl)?.stringValue() {
            community.thumbnailUrl = URL(string: thumbnailUrl)
        }
    }

    func extractChannelCommunity(fromHtmlData htmlData: Data, community: Community) {
        var error: NSError?
        let htmlDocument: ONOXMLDocument!
        do {
            htmlDocument = try ONOXMLDocument.htmlDocument(with: htmlData)
        } catch let error1 as NSError {
            error = error1
            log.error("\(error?.debugDescription ?? "")")
            htmlDocument = nil
        }
        let rootElement = htmlDocument?.rootElement

        if rootElement == nil {
            log.error("rootElement is nil")
            return
        }

        let xpathTitle = "//*[@id=\"head_cp_breadcrumb\"]/h1/a"
        community.title = rootElement?.firstChild(withXPath: xpathTitle)?.stringValue().stringByRemovingRegexp(pattern: "\n")

        let xpathThumbnailUrl = "//*[@id=\"cp_symbol\"]/span/a/img/@data-original"
        if let thumbnailUrl = rootElement?.firstChild(withXPath: xpathThumbnailUrl)?.stringValue() {
            community.thumbnailUrl = URL(string: thumbnailUrl)
        }
    }

    // MARK: - Username
    func extractUsername(fromHtmlData htmlData: Data) -> String? {
        var error: NSError?
        let htmlDocument: ONOXMLDocument!
        do {
            htmlDocument = try ONOXMLDocument.htmlDocument(with: htmlData)
        } catch let error1 as NSError {
            error = error1
            htmlDocument = nil
            log.error("\(error?.debugDescription ?? "")")
        }
        let rootElement = htmlDocument?.rootElement

        // /html/body/div[3]/div[2]/h2/text() -> other's userpage
        // /html/body/div[4]/div[2]/h2/text() -> my userpage, contains '他のユーザーから見たあなたのプロフィールです。' box
        let username = rootElement?.firstChild(withXPath: "/html/body/*/div[2]/h2")?.stringValue()
        let cleansed = username?.stringByRemovingRegexp(pattern: "(?:さん|)\\s*$")

        return cleansed
    }

    // MARK: - Heartbeat
    func extractHeartbeat(fromXmlData xmlData: Data) -> Heartbeat? {
        var error: NSError?
        let xmlDocument: XMLDocument?
        do {
            xmlDocument = try XMLDocument(data: xmlData, options: convertToXMLNodeOptions(0))
        } catch let error1 as NSError {
            error = error1
            xmlDocument = nil
            log.error("\(error?.debugDescription ?? "")")
        }
        let rootElement = xmlDocument?.rootElement()

        let heartbeat = Heartbeat()
        let baseXPath = "/heartbeat/"

        if let status = rootElement?.firstStringValue(forXPath: baseXPath + "@status") {
            heartbeat.status = Heartbeat.statusFromString(status: status)
        }

        if heartbeat.status == Heartbeat.Status.ok {
            heartbeat.watchCount = rootElement?.firstIntValue(forXPath: baseXPath + "watchCount")
            heartbeat.commentCount = rootElement?.firstIntValue(forXPath: baseXPath + "commentCount")
            heartbeat.freeSlotNum = rootElement?.firstIntValue(forXPath: baseXPath + "freeSlotNum")
            heartbeat.isRestrict = rootElement?.firstIntValue(forXPath: baseXPath + "is_restrict")
            heartbeat.ticket = rootElement?.firstStringValue(forXPath: baseXPath + "ticket")
            heartbeat.waitTime = rootElement?.firstIntValue(forXPath: baseXPath + "waitTime")
        } else if heartbeat.status == Heartbeat.Status.fail {
            if let errorCode = rootElement?.firstStringValue(forXPath: baseXPath + "error/code") {
                heartbeat.errorCode = Heartbeat.errorCodeFromString(errorCode: errorCode)
            }
        }

        return heartbeat
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToXMLNodeOptions(_ input: Int) -> XMLNode.Options {
    return XMLNode.Options(rawValue: UInt(input))
}
