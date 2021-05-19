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
    (0..<2, 0.50),
    (2..<4, 0.55),
    (4..<7, 0.60),
    (7..<10, 0.65),
    (10..<100, 0.75)
]
private let kRefreshChatQueueThreshold = 30

private let kCleanCommentPatterns = [
    ("https?://[\\w!?/+\\-_~;.,*&@#$%()'\\[\\]=]+", " URL "),
    ("(w|ｗ){2,}", " わらわら"),
    ("(w|ｗ)$", " わら"),
    ("(8|８){3,}", "ぱちぱち")
]

@available(macOS 10.14, *)
final class SpeechManager: NSObject {
    // MARK: - Properties
    static let shared = SpeechManager()

    private var chatQueue: [Chat] = []
    private var voiceSpeed = kVoiceSpeedMap[0].speed
    private var voiceVolume = 100
    private var timer: Timer?
    private let synthesizer = AVSpeechSynthesizer()

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

    // min/max: 0-100
    func setVoiceVolume(_ volume: Int) {
        voiceVolume = max(min(volume, 100), 0)
        log.debug("set volume: \(voiceVolume)")
    }

    func enqueue(chat: Chat) {
        guard chat.premium == .ippan || chat.premium == .premium else { return }

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

        let utterance = AVSpeechUtterance.init(string: cleanComment(from: chat.comment))
        voiceSpeed = adjustedVoiceSpeed(chatQueueCount: chatQueue.count, currentVoiceSpeed: voiceSpeed)
        utterance.rate = voiceSpeed
        utterance.volume = Float(voiceVolume) / 100.0
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
        var cleaned = comment
        kCleanCommentPatterns.forEach {
            cleaned = cleaned.stringByReplacingRegexp(pattern: $0.0, with: $0.1)
        }
        return cleaned
    }
}
