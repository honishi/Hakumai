//
//  SpeechManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AVFoundation

private let kDequeuChatTimerInterval: TimeInterval = 0.5

private let kVoiceSpeedMap: [(queuCountRange: CountableRange<Int>, speed: Float)] = [
    (0..<3, 0.6),
    (3..<6, 0.65),
    (6..<9, 0.7),
    (9..<12, 0.75),
    (12..<100, 0.8)
]
private let kRefreshChatQueueThreshold = 30

private let kCleanCommentPatterns = [
    "^/\\w+ \\w+ \\w+ "
]

@available(macOS 10.14, *)
final class SpeechManager: NSObject {
    // MARK: - Properties
    static let sharedManager = SpeechManager()

    private var chatQueue: [Chat] = []
    private var voiceSpeed = kVoiceSpeedMap[0].speed
    private var voiceVolume = 100
    private var timer: Timer?
    private let synthesizer = AVSpeechSynthesizer()
    private var liveStartedDate: Date?

    // MARK: - Object Lifecycle
    override init() {
        super.init()
    }

    // MARK: - Public Functions
    func startManager() {
        guard timer == nil else { return }
        // use explicit main queue to ensure that the timer continues to run even when caller thread ends.
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(
                timeInterval: kDequeuChatTimerInterval,
                target: self,
                selector: #selector(SpeechManager.dequeue(_:)),
                userInfo: nil,
                repeats: true)
        }
        log.debug("started speech manager.")
    }

    func stopManager() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        chatQueue.removeAll()
        log.debug("stopped speech manager.")
    }

    func updateLiveStartedDate(_ date: Date = Date()) {
        liveStartedDate = date
    }

    // min/max: 0-100
    func setVoiceVolume(_ volume: Int) {
        voiceVolume = max(min(volume, 100), 0)
        log.debug("set volume: \(voiceVolume)")
    }

    func enqueue(chat: Chat) {
        guard let started = liveStartedDate,
              Date().timeIntervalSince(started) > 5 else {
            // Skip enqueuing since there's possibility that we receive lots of
            // messages for this time slot.
            log.debug("Skip enqueuing early chats.")
            return
        }

        guard chat.premium == .ippan || chat.premium == .premium || chat.premium == .bsp else { return }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        chatQueue.append(chat)
    }

    @objc func dequeue(_ timer: Timer?) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard !synthesizer.isSpeaking, 0 < chatQueue.count else { return }

        guard let chat = chatQueue.first else { return }
        chatQueue.removeFirst()
        guard let comment = chat.comment else { return }

        let utterance = AVSpeechUtterance.init(string: cleanComment(from: comment))
        utterance.rate = adjustedVoiceSpeed(chatQueueCount: chatQueue.count, currentVoiceSpeed: voiceSpeed)
        utterance.volume = Float(voiceVolume) / 100
        let voice = AVSpeechSynthesisVoice.init(language: "ja-JP")
        utterance.voice = voice
        synthesizer.speak(utterance)
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
    private func adjustedVoiceSpeed(chatQueueCount count: Int, currentVoiceSpeed: Float) -> Float {
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
