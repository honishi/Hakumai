//
//  SpeechManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kDequeuChatTimerInterval: TimeInterval = 0.5

private let kVoiceSpeedMap: [(queuCountRange: CountableRange<Int>, speed: Int)] = [
    (0..<5, 100),
    (5..<10, 125),
    (10..<15, 150),
    (15..<20, 175),
    (20..<100, 200),
]
private let kRefreshChatQueueThreshold = 30

private let kCleanCommentPatterns = [
    "^/\\w+ \\w+ \\w+ ",
]

class SpeechManager: NSObject {
    // MARK: - Properties
    static let sharedManager = SpeechManager()
    
    private var chatQueue: [Chat] = []
    private var voiceSpeed = kVoiceSpeedMap[0].speed
    private var timer: Timer?
    private var yukkuroidAvailable = false
    
    // MARK: - Object Lifecycle
    override init() {
        super.init()
    }
    
    // MARK: - Public Functions
    func startManager() {
        guard timer == nil else {
            return
        }
        
        // use explicit main queue to ensure that the timer continues to run even when caller thread ends.
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: kDequeuChatTimerInterval, target: self,
                selector: #selector(SpeechManager.dequeue(_:)), userInfo: nil, repeats: true)
        }
        
        logger.debug("started speech manager.")
    }
    
    func stopManager() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
        
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        chatQueue.removeAll()
        
        logger.debug("stopped speech manager.")
    }
    
    func enqueue(chat: Chat) {
        guard YukkuroidClient.isAvailable() else {
            return
        }
        
        guard chat.premium == .ippan || chat.premium == .premium || chat.premium == .bsp else {
            return
        }
        
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        chatQueue.append(chat)
    }
    
    func dequeue(_ timer: Timer?) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        let currentAvailable = YukkuroidClient.isAvailable()
        
        if yukkuroidAvailable != currentAvailable {
            chatQueue.removeAll()
            yukkuroidAvailable = currentAvailable
        }
        
        if 0 == chatQueue.count || YukkuroidClient.isStillPlaying(0) {
            return
        }
        
        guard let chat = chatQueue.first else {
            return
        }
        chatQueue.removeFirst()
        
        guard let comment = chat.comment else {
            return
        }
        
        voiceSpeed = adjustedVoiceSpeed(chatQueueCount: chatQueue.count, currentVoiceSpeed: voiceSpeed)
        YukkuroidClient.setVoiceSpeed(Int32(voiceSpeed), setting: 0)
        YukkuroidClient.setKanjiText(cleanComment(from: comment))
        YukkuroidClient.pushPlayButton(0)
    }

    func refreshChatQueueIfQueuedTooMuch() -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if kRefreshChatQueueThreshold < chatQueue.count {
            chatQueue.removeAll()
            return true
        }
        
        return false
    }
    
    // MARK: - Private Functions
    private func adjustedVoiceSpeed(chatQueueCount count: Int, currentVoiceSpeed: Int) -> Int {
        var candidateSpeed = kVoiceSpeedMap[0].speed
        
        if count == 0 {
            return candidateSpeed
        }
        
        for (queueCountRange, speed) in kVoiceSpeedMap {
            if queueCountRange.contains(count) {
                candidateSpeed = speed
                break
            }
        }
        
        return currentVoiceSpeed < candidateSpeed ? candidateSpeed : currentVoiceSpeed
    }
    
    // define as 'internal' for test
    func cleanComment(from comment: String) -> String {
        var clean: String = ""
        
        for pattern in kCleanCommentPatterns {
            clean = comment.stringByRemovingRegexp(pattern: pattern)
        }
        
        return clean
    }
}
