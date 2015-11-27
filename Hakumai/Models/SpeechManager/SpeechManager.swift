//
//  SpeechManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

private let kDequeuChatTimerInterval: NSTimeInterval = 0.5

private let kVoiceSpeedMap: [(queuCountRange: Range<Int>, speed: Int)] = [
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
    private var timer: NSTimer?
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
        dispatch_async(dispatch_get_main_queue()) {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(kDequeuChatTimerInterval, target: self,
                selector: "dequeueChat:", userInfo: nil, repeats: true)
        }
        
        XCGLogger.debug("started speech manager.")
    }
    
    func stopManager() {
        dispatch_async(dispatch_get_main_queue()) {
            self.timer?.invalidate()
            self.timer = nil
        }
        
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        chatQueue.removeAll()
        
        XCGLogger.debug("stopped speech manager.")
    }
    
    func enqueueChat(chat: Chat) {
        guard YukkuroidClient.isAvailable() else {
            return
        }
        
        guard chat.premium == .Ippan || chat.premium == .Premium || chat.premium == .BSP else {
            return
        }
        
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        chatQueue.append(chat)
    }
    
    func dequeueChat(timer: NSTimer?) {
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
        
        voiceSpeed = adjustedVoiceSpeedWithChatQueueCount(chatQueue.count, currentVoiceSpeed: voiceSpeed)
        YukkuroidClient.setVoiceSpeed(Int32(voiceSpeed), setting: 0)
        YukkuroidClient.setKanjiText(cleanComment(comment))
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
    private func adjustedVoiceSpeedWithChatQueueCount(count: Int, currentVoiceSpeed: Int) -> Int {
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
    func cleanComment(comment: String) -> String {
        var clean: String = ""
        
        for pattern in kCleanCommentPatterns {
            clean = comment.stringByRemovingPattern(pattern)
        }
        
        return clean
    }
}
