//
//  CommentCopier.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/18.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class CommentCopier: CommentCopierType {
    let live: Live
    let messageContainer: MessageContainer
    let nicoManager: NicoManagerType
    let handleNameManager: HandleNameManager

    init(live: Live, messageContainer: MessageContainer, nicoManager: NicoManagerType, handleNameManager: HandleNameManager) {
        self.live = live
        self.messageContainer = messageContainer
        self.nicoManager = nicoManager
        self.handleNameManager = handleNameManager
    }
}

extension CommentCopier {
    static func make(live: Live, messageContainer: MessageContainer, nicoManager: NicoManagerType, handleNameManager: HandleNameManager) -> CommentCopierType {
        let copier = CommentCopier(
            live: live,
            messageContainer: messageContainer,
            nicoManager: nicoManager,
            handleNameManager: handleNameManager)
        return copier
    }

    func copy() {
        let comments = messageContainer
            .filteredMessages
            .map { $0.toComment(live: live, nicoManager: nicoManager, handleNameManager: handleNameManager) }
            .reduce("") { $0 + "\($1)\n" }
        comments.copyToPasteBoard()
    }
}

private extension Message {
    func toComment(live: Live, nicoManager: NicoManagerType, handleNameManager: HandleNameManager) -> String {
        var number = ""
        var comment = ""
        var user = ""
        var premium = ""
        switch content {
        case .system(let message):
            comment = message.message
        case .chat(let message):
            number = String(message.no)
            comment = message.comment
            user = message.toResolvedUserId(
                live: live,
                nicoManager: nicoManager,
                handleNameManager: handleNameManager)
            premium = message.toResolvedPremium()
        case .debug(let message):
            comment = message.message
        }
        comment = comment.trimEnter()
        return "\(number)\t\(comment)\t\(user)\t\(premium)"
    }
}

private extension ChatMessage {
    func toResolvedUserId(live: Live, nicoManager: NicoManagerType, handleNameManager: HandleNameManager) -> String {
        var resolved = userId
        if let handleName = handleNameManager.handleName(for: userId, in: live.communityId) {
            resolved = "\(handleName) (\(userId))"
        } else if userId.isRawUserId, let accountName = nicoManager.cachedUserName(for: userId) {
            resolved = "\(accountName) (\(userId))"
        }
        return resolved
    }

    func toResolvedPremium() -> String {
        return premium.label()
    }
}

private extension String {
    func trimEnter() -> String {
        return stringByRemovingRegexp(pattern: "\n")
    }
}
