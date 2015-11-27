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
    func addChat(chat: Chat) {
        guard YukkuroidClient.isAvailable() else {
            return
        }
        
        guard chat.premium == .Ippan || chat.premium == .Premium || chat.premium == .BSP else {
            return
        }
        
        objc_sync_enter(self)
        chatQueue.append(chat)
        objc_sync_exit(self)
    }
    
    func dequeueChat(timer: NSTimer?) {
        let currentAvailable = YukkuroidClient.isAvailable()
        
        if yukkuroidAvailable != currentAvailable {
            objc_sync_enter(self)
            chatQueue.removeAll()
            objc_sync_exit(self)
            yukkuroidAvailable = currentAvailable
        }
        
        objc_sync_enter(self)
        let shouldSkip = 0 == chatQueue.count || YukkuroidClient.isStillPlaying(0)
        objc_sync_exit(self)
        
        if shouldSkip {
            return
        }
        
        objc_sync_enter(self)
        let chat: Chat! = chatQueue.first
        if chat != nil {
            chatQueue.removeFirst()
        }
        let chatQueueCount = chatQueue.count
        objc_sync_exit(self)
        
        guard chat != nil && chat.comment != nil else {
            return
        }
        // XCGLogger.debug("\(chat.comment)")
        
        voiceSpeed = adjustedVoiceSpeedWithChatQueueCount(chatQueueCount, currentVoiceSpeed: voiceSpeed)
        YukkuroidClient.setVoiceSpeed(Int32(voiceSpeed), setting: 0)
        YukkuroidClient.setKanjiText(cleanComment(chat.comment!))
        YukkuroidClient.pushPlayButton(0)
    }

    func refreshChatQueueIfQueuedTooMuch() -> Bool {
        var refreshed = false
        
        objc_sync_enter(self)
        if kRefreshChatQueueThreshold < chatQueue.count {
            chatQueue.removeAll()
            refreshed = true
        }
        objc_sync_exit(self)
        
        return refreshed
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
