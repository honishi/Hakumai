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

    func copy(format: CommentCopyFormat, completion: (() -> Void)?) {
        switch format {
        case .allColumns:
            preCacheUserIds {
                self.copyMessages(format: format)
                completion?()
            }
        case .numberAndCommentOnly:
            copyMessages(format: format)
            completion?()
        }
    }
}

private extension CommentCopier {
    func preCacheUserIds(completion: @escaping () -> Void) {
        let userIds = messageContainer
            .filteredMessages
            .toRawUserIds()
        log.debug(userIds)
        resolveUserIds(userIds) { completion() }
    }

    func resolveUserIds(_ userIds: [String], completion: @escaping () -> Void) {
        guard let userId = userIds.first else {
            completion()
            return
        }
        let resolveOnceCompleted = {
            var _userIds = userIds
            _userIds.removeFirst()
            DispatchQueue.global(qos: .default).async {
                self.resolveUserIds(_userIds, completion: completion)
            }
        }
        if let cached = nicoManager.cachedUserName(for: userId) {
            log.debug("Already cached: \(cached)")
            resolveOnceCompleted()
            return
        }
        nicoManager.resolveUsername(for: userId) {
            log.debug("Pre-cached: \($0 ?? "")")
            resolveOnceCompleted()
        }
    }

    func copyMessages(format: CommentCopyFormat) {
        let copiedLines = messageContainer
            .filteredMessages
            .filter { !$0.isSystemMessage }
            .map { $0.toComment(live: live, nicoManager: nicoManager, handleNameManager: handleNameManager, format: format) }
        let prefixLines = [
            "放送タイトル：\(live.title)",
            "配信者名：\(live.programProvider.name)",
            ""
        ]
        let comments = (prefixLines + [format.headerLine] + copiedLines).joined(separator: "\n")
        comments.copyToPasteBoard()
    }
}

private extension CommentCopyFormat {
    var headerLine: String {
        switch self {
        case .allColumns:
            return "コメント番号\tコメント\tユーザー\t種別"
        case .numberAndCommentOnly:
            return "コメント番号\tコメント"
        }
    }
}

private extension Array where Element == Message {
    func toRawUserIds() -> [String] {
        let userIds = map { message -> String? in
            switch message.content {
            case .system, .debug:
                return nil
            case .chat(let chat):
                return chat.userId
            }
        }
        .compactMap { $0 }
        .filter { $0.isRawUserId }
        return [String](Set(userIds))
    }
}

private extension Message {
    var isSystemMessage: Bool {
        switch content {
        case .system:
            return true
        case .chat, .debug:
            return false
        }
    }

    func toComment(live: Live, nicoManager: NicoManagerType, handleNameManager: HandleNameManager, format: CommentCopyFormat) -> String {
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
            premium = message.premium.label()
        case .debug(let message):
            comment = message.message
        }
        comment = comment.trimEnter()
        switch format {
        case .allColumns:
            return "\(number)\t\(comment)\t\(user)\t\(premium)"
        case .numberAndCommentOnly:
            return "\(number)\t\(comment)"
        }
    }
}

private extension ChatMessage {
    func toResolvedUserId(live: Live, nicoManager: NicoManagerType, handleNameManager: HandleNameManager) -> String {
        var resolved = userId
        if let handleName = handleNameManager.handleName(for: userId, in: live.programProvider.programProviderId) {
            resolved = "\(handleName) (\(userId))"
        } else if userId.isRawUserId, let accountName = nicoManager.cachedUserName(for: userId) {
            resolved = "\(accountName) (\(userId))"
        }
        return resolved
    }
}

private extension String {
    func trimEnter() -> String {
        return stringByRemovingRegexp(pattern: "\n")
    }
}
