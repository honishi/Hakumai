//
//  ChatContainer.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// thread safe chat container
final class MessageContainer {
    // MARK: - Properties
    // MARK: Public
    var enableMuteUserIds = false
    var muteUserIds = [[String: String]]()
    var enableMuteWords = false
    var muteWords = [[String: String]]()
    var enableEmotionMessage = true
    var enableDebugMessage = false

    private(set) var filteredMessages = [Message]()

    // MARK: Private
    private var messageNo = 0
    private var sourceMessages = [Message]()
    private var firstChat = [String: Bool]()
    private var rebuildingFilteredMessages = false
    private var calculatingActive = false
}

extension MessageContainer {
    // MARK: - Basic Operation to Content Array
    @discardableResult
    func append(systemMessage: String) -> (appended: Bool, count: Int) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let message = Message(messageNo: messageNo, system: systemMessage)
        return append(message: message)
    }

    @discardableResult
    func append(chat: Chat) -> (appended: Bool, count: Int) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        let isFirst = chat.premium.isUser && firstChat[chat.userId] == nil
        if isFirst {
            firstChat[chat.userId] = true
        }
        let message = Message(messageNo: messageNo, chat: chat, isFirst: isFirst)
        return append(message: message)
    }

    @discardableResult
    func append(debug: String) -> (appended: Bool, count: Int) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let message = Message(messageNo: messageNo, debug: debug)
        return append(message: message)
    }

    private func append(message: Message) -> (appended: Bool, count: Int) {
        messageNo += 1
        sourceMessages.append(message)
        let appended = appendIfConditionMet(
            message: message, into: &filteredMessages)
        let count = filteredMessages.count
        return (appended, count)
    }

    func count() -> Int {
        objc_sync_enter(self)
        let count = filteredMessages.count
        objc_sync_exit(self)
        return count
    }

    subscript (index: Int) -> Message {
        objc_sync_enter(self)
        let content = filteredMessages[index]
        objc_sync_exit(self)
        return content
    }

    func messages(fromUserId userId: String) -> [Message] {
        var userMessages = [Message]()

        objc_sync_enter(self)
        for message in sourceMessages {
            switch message.content {
            case .system, .debug:
                continue
            case .chat(let chat):
                guard chat.userId == userId else { continue }
                userMessages.append(message)
            }
        }
        objc_sync_exit(self)

        return userMessages
    }

    func removeAll() {
        objc_sync_enter(self)
        sourceMessages.removeAll(keepingCapacity: false)
        filteredMessages.removeAll(keepingCapacity: false)
        firstChat.removeAll(keepingCapacity: false)
        messageNo = 0
        objc_sync_exit(self)
    }

    // MARK: - Utility
    func calculateActive(completion: @escaping (Int?) -> Void) {
        if rebuildingFilteredMessages {
            log.debug("detected rebuilding filtered messages, so skip calculating active.")
            completion(nil)
            return
        }

        if calculatingActive {
            log.debug("detected duplicate calculating, so skip calculating active.")
            completion(nil)
            return
        }

        objc_sync_enter(self)
        calculatingActive = true
        objc_sync_exit(self)

        // log.debug("calcurating active")

        // swift way to use background gcd, http://stackoverflow.com/a/25070476
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            var activeUsers = [String: Bool]()
            let fiveMinutesAgo = Date(timeIntervalSinceNow: (Double)(-5 * 60))

            // log.debug("start counting active")
            objc_sync_enter(self)
            let count = self.sourceMessages.count
            objc_sync_exit(self)

            var i = count
            while 0 < i {
                objc_sync_enter(self)
                let message = self.sourceMessages[i - 1]
                objc_sync_exit(self)
                i -= 1
                guard case let .chat(chat) = message.content, chat.isUser else { continue }
                // is "chat.date < fiveMinutesAgo" ?
                if chat.date.compare(fiveMinutesAgo) == .orderedAscending {
                    break
                }
                activeUsers[chat.userId] = true
            }

            // log.debug("end counting active")
            completion(activeUsers.count)

            objc_sync_enter(self)
            self.calculatingActive = false
            objc_sync_exit(self)
        }
    }

    func rebuildFilteredMessages(completion: @escaping () -> Void) {
        // 1st pass:
        // copy and filter source messages. this could be long operation so use background thread
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            // log.debug("started 1st pass rebuilding filtered messages (bg section)")

            var workingMessages = [Message]()
            let sourceCount = self.sourceMessages.count

            for i in 0..<sourceCount {
                self.appendIfConditionMet(
                    message: self.sourceMessages[i],
                    into: &workingMessages)
            }

            // log.debug("completed 1st pass")

            // 2nd pass:
            // we need to replace old filtered messages with new one with the following conditions;
            // - exclusive to ui updates, so use main thread
            // - atomic to any other operation like append, count, calcurate and so on, so use objc_sync_enter/exit
            DispatchQueue.main.async {
                // log.debug("started 2nd pass rebuilding filtered messages (critical section)")

                objc_sync_enter(self)
                self.rebuildingFilteredMessages = true

                self.filteredMessages = workingMessages
                // log.debug("copied working messages to filtered messages")

                let deltaCount = self.sourceMessages.count
                for i in sourceCount..<deltaCount {
                    self.appendIfConditionMet(
                        message: self.sourceMessages[i],
                        into: &self.filteredMessages)
                }
                // log.debug("copied delta messages \(sourceCount)..<\(deltaCount)")

                self.rebuildingFilteredMessages = false
                objc_sync_exit(self)

                // log.debug("completed 2nd pass")
                log.debug("completed to rebuild filtered messages")

                completion()
            }
        }
    }
}

// MARK: - Internal Functions
private extension MessageContainer {
    // MARK: Filtered Message Append Utility
    @discardableResult
    func appendIfConditionMet(message: Message, into messages: inout [Message]) -> Bool {
        var appended = false
        if shouldAppend(message: message) {
            messages.append(message)
            appended = true
        }
        return appended
    }

    func shouldAppend(message: Message) -> Bool {
        switch message.content {
        case .system:
            return true
        case .chat(let chat):
            return shouldAppendByMuteWords(chat)
                && shouldAppendByUserId(chat)
                && shouldAppendByEmotion(chat)
        case .debug:
            return enableDebugMessage
        }
    }

    func shouldAppendByMuteWords(_ chat: ChatMessage) -> Bool {
        guard enableMuteWords else { return true }
        for muteWord in muteWords {
            if let word = muteWord[MuteUserWordKey.word],
               chat.comment.lowercased().range(of: word.lowercased()) != nil {
                return false
            }
        }
        return true
    }

    func shouldAppendByUserId(_ chat: ChatMessage) -> Bool {
        guard enableMuteUserIds else { return true }
        for muteUserId in muteUserIds where muteUserId[MuteUserIdKey.userId] == chat.userId {
            return false
        }
        return true
    }

    func shouldAppendByEmotion(_ chat: ChatMessage) -> Bool {
        if enableEmotionMessage {
            return true
        }
        let isEmotion = chat.slashCommand == .emotion
        return !isEmotion
    }
}
