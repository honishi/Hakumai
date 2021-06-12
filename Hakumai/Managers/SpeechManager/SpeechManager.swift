//
//  SpeechManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AVFoundation

private let dequeuChatTimerInterval: TimeInterval = 0.5

private let voiceSpeedMap: [(commentLengthRange: CountableRange<Int>, speed: Float)] = [
    (0..<20, 0.50),
    (20..<40, 0.55),
    (40..<70, 0.60),
    (70..<100, 0.65),
    (100..<Int.max, 0.75)
]
private let refreshChatQueueThreshold = 30

// https://stackoverflow.com/a/38409026/13220031
// See unicode list at https://0g0.org/ or https://0g0.org/unicode-list/
// See unicode search at https://www.marbacka.net/msearch/tool.php#chr2enc
private let emojiPattern = "[\\U0001F000-\\U0001F9FF]"
private let lineBreakPattern = "\n"

private let cleanCommentPatterns = [
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
    private var voiceSpeed = voiceSpeedMap[0].speed
    private var voiceVolume = 100
    private var timer: Timer?
    private let synthesizer = AVSpeechSynthesizer()

    private let emojiRegexp = try? NSRegularExpression(pattern: emojiPattern, options: [])
    private let lineBreakRegexp = try? NSRegularExpression(pattern: lineBreakPattern, options: [])

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
                timeInterval: dequeuChatTimerInterval,
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
        guard isAcceptableComment(chat.comment) else { return }

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
        voiceSpeed = adjustedVoiceSpeed(
            currentCommentLength: chat.comment.count,
            remainingCommentLength: chatQueue.map { $0.comment.count }.reduce(0, +),
            currentVoiceSpeed: voiceSpeed)
        utterance.rate = voiceSpeed
        utterance.volume = Float(voiceVolume) / 100.0
        let voice = AVSpeechSynthesisVoice.init(language: "ja-JP")
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    func refreshChatQueueIfQueuedTooMuch() -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if refreshChatQueueThreshold < chatQueue.count {
            chatQueue.removeAll()
            return true
        }

        return false
    }

    // MARK: - Private Functions
    private func adjustedVoiceSpeed(currentCommentLength current: Int, remainingCommentLength remaining: Int, currentVoiceSpeed: Float) -> Float {
        let total = current + remaining
        var candidateSpeed = voiceSpeedMap[0].speed
        for (commentLengthRange, speed) in voiceSpeedMap {
            if commentLengthRange.contains(total) {
                candidateSpeed = speed
                break
            }
        }
        let adjusted = remaining == 0 ? candidateSpeed : max(currentVoiceSpeed, candidateSpeed)
        log.debug("current: \(current) remaining: \(remaining) total: \(total) candidate: \(candidateSpeed) adjusted: \(adjusted)")
        return adjusted
    }

    // define as 'internal' for test
    func isAcceptableComment(_ comment: String) -> Bool {
        guard let emojiRexexp = emojiRegexp, let newLineRegexp = lineBreakRegexp else {
            return true
        }
        return comment.count < 100 &&
            emojiRexexp.matchCount(in: comment) < 5 &&
            newLineRegexp.matchCount(in: comment) < 3
    }

    // define as 'internal' for test
    func cleanComment(from comment: String) -> String {
        var cleaned = comment
        cleanCommentPatterns.forEach {
            cleaned = cleaned.stringByReplacingRegexp(pattern: $0.0, with: $0.1)
        }
        return cleaned
    }
}

private extension NSRegularExpression {
    func matchCount(in text: String) -> Int {
        return numberOfMatches(in: text, options: [], range: NSRange(0..<text.count))
    }
}
