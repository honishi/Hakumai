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

private let kVoiceSpeedNormal = 100
private let kVoiceSpeedFast = 150
private let kVoiceSpeedVeryFast = 200
private let kVoiceSpeedVeryVeryFast = 250

private let kRefreshChatQueueThreshold = 20

private let kCleanCommentPatterns = [
    "^/\\w+ \\w+ \\w+ ",
]

class SpeechManager: NSObject {
    // MARK: - Properties
    static let sharedManager = SpeechManager()
    
    private var chatQueue: [Chat] = []
    private var voiceSpeed = kVoiceSpeedNormal
    private var timer: NSTimer?
    private var yukkuroidAvailable = false
    
    // MARK: - Object Lifecycle
    override init() {
        super.init()
        startDequeueTimer()
    }
    
    // MARK: - Public Functions
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
    private func startDequeueTimer() {
        guard timer == nil else {
            return
        }
        
        // use explicit main queue to ensure that the timer continues to run even when caller thread ends.
        dispatch_async(dispatch_get_main_queue()) {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(kDequeuChatTimerInterval, target: self,
                selector: "dequeueChat:", userInfo: nil, repeats: true)
        }
    }
    
    private func adjustedVoiceSpeedWithChatQueueCount(count: Int, currentVoiceSpeed: Int) -> Int {
        if count == 0 {
            return kVoiceSpeedNormal
        }
        
        var candidateSpeed: Int
        
        switch count {
        case 0..<5:
            candidateSpeed = kVoiceSpeedNormal
        case 5..<10:
            candidateSpeed = kVoiceSpeedFast
        case 10..<15:
            candidateSpeed = kVoiceSpeedVeryFast
        default:
            candidateSpeed = kVoiceSpeedVeryVeryFast
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
