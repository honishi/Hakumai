//
//  SpeechManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AVFoundation

private let dequeuChatTimerInterval: TimeInterval = 0.25

private let voiceSpeedMap: [(commentLengthRange: CountableRange<Int>, speed: Float)] = [
    (0..<40, 0.50),
    (40..<80, 0.55),
    (80..<120, 0.60),
    (120..<160, 0.65),
    (160..<Int.max, 0.75)
]
private let refreshChatQueueThreshold = 30
private let recentChatsThreshold = 50

private let voicevoxSpeedMap: [(commentLengthRange: CountableRange<Int>, speed: Float)] = [
    (0..<30, 1),
    (30..<60, 1.25),
    (60..<90, 1.5),
    (90..<120, 1.75),
    (120..<Int.max, 2)
]

// https://stackoverflow.com/a/38409026/13220031
// See unicode list at https://0g0.org/ or https://0g0.org/unicode-list/
// See unicode search at https://www.marbacka.net/msearch/tool.php#chr2enc
private let emojiPattern = "[\\U0001F000-\\U0001F9FF]"
private let lineBreakPattern = "\n"
// https://stackoverflow.com/a/1660739/13220031
// private let repeatedCharPattern = "(.)\\1{9,}"
// https://so-zou.jp/software/tech/programming/tech/regular-expression/meta-character/variable-width-encoding.htm#no1
private let repeatedKanjiPattern = "(\\p{Han})\\1{9,}"

private let cleanCommentPatterns = [
    ("https?://[\\w!?/+\\-_~;.,*&@#$%()'\\[\\]=]+", " URL "),
    ("(w|ｗ){2,}", " わらわら"),
    ("(w|ｗ)$", " わら"),
    ("(8|８){3,}", "ぱちぱち"),
    ("ニコ生(?!放送)", "ニコなま"),
    ("初見", "しょけん")
]

@available(macOS 10.14, *)
final class _Synthesizer {
    static let shared = _Synthesizer()
    let synthesizer = AVSpeechSynthesizer()
}

final class SpeechManager: NSObject {
    // MARK: - Properties
    private var chatQueue: [Chat] = []
    private var recentChats: [Chat] = []
    private var voiceSpeed = voiceSpeedMap[0].speed
    private var voiceVolume = 100
    private var voiceSpeaker = 0
    private var timer: Timer?

    // swiftlint:disable force_try
    private let emojiRegexp = try! NSRegularExpression(pattern: emojiPattern, options: [])
    private let lineBreakRegexp = try! NSRegularExpression(pattern: lineBreakPattern, options: [])
    private let repeatedKanjiRegexp = try! NSRegularExpression(pattern: repeatedKanjiPattern, options: [])
    // swiftlint:enable force_try

    private let voicevoxWrapper: VoicevoxWrapperType = VoicevoxWrapper()
    private var player: AVAudioPlayer = AVAudioPlayer()
    private var requestingAudioLoad = false
    private var audioQueue: [VoicevoxAudio] = []
    private var voicevoxSpeed = voicevoxSpeedMap[0].speed

    // Debug: for logger
    private var _chatQueueCount = -1
    private var _audioQueueCount = -1
    private var _voiceVoxSpeed = -1
    private var _preloadMessage = ""

    // MARK: - Object Lifecycle
    override init() {
        super.init()
        configure()
    }
}

extension SpeechManager {
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
        audioQueue.removeAll()
    }

    func stopManager() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        chatQueue.removeAll()
        recentChats.removeAll()
        log.debug("stopped speech manager.")
        audioQueue.removeAll()
    }

    // min/max: 0-100
    func setVoiceVolume(_ volume: Int) {
        voiceVolume = max(min(volume, 100), 0)
        log.debug("set volume: \(voiceVolume)")
    }

    func setVoiceSpeaker(_ speaker: Int) {
        voiceSpeaker = speaker
        log.debug("set speaker: \(speaker)")
    }

    func enqueue(chat: Chat) {
        guard [.ippan, .premium, .ippanTransparent].contains(chat.premium) else { return }
        guard isAcceptableComment(chat.comment) else { return }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        chatQueue.append(chat)

        let audio = VoicevoxAudio(audioKey: chat.audioKey, comment: cleanComment(from: chat.comment))
        audioQueue.append(audio)
        preloadFromAudioQueue()

        recentChats.append(chat)
        if recentChats.count > recentChatsThreshold {
            recentChats.remove(at: 0)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    @objc func dequeue(_ timer: Timer?) {
        guard #available(macOS 10.14, *) else { return }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        logAudioQueue()
        preloadFromAudioQueue()

        // log.debug("\(requestingAudioLoad), \(player.isPlaying)")
        guard !requestingAudioLoad, !player.isPlaying else { return }

        guard !_Synthesizer.shared.synthesizer.isSpeaking,
              0 < chatQueue.count else { return }

        guard let chat = chatQueue.first else { return }
        chatQueue.removeFirst()

        let isUniqueComment = recentChats.filter { $0.comment == chat.comment }.count == 1
        let isShortComment = chat.comment.count < 10
        guard isUniqueComment || isShortComment else {
            log.debug("skip duplicate speech comment. [\(chat.comment)]")
            removeFromAudioQueue(audioKey: chat.audioKey)
            return
        }

        voiceSpeed = adjustedVoiceSpeed(
            currentCommentLength: chat.comment.count,
            remainingCommentLength: chatQueue.map { $0.comment.count }.reduce(0, +),
            currentVoiceSpeed: voiceSpeed)

        /*
         speak(comment: chat.cleanComment,
         speed: voiceSpeed,
         volume: Float(voiceVolume) / 100.0)
         */

        voicevoxSpeed = adjustedVoicevoxSpeed(
            currentCommentLength: chat.comment.count,
            remainingCommentLength: chatQueue.map { $0.comment.count }.reduce(0, +),
            currentVoiceSpeed: voicevoxSpeed)

        guard let audio = audioQueue.firstFilter(audioKey: chat.audioKey) else { return }

        switch audio.loadStatus {
        case .notLoaded:
            audio.startLoad(
                speedScale: voicevoxSpeed,
                volumeScale: voiceVolume.asVoicevoxVolumeScale,
                speaker: voiceSpeaker)
            audio.setLoadStatusListener { [weak self] in
                guard let me = self else { return }
                me.handleLoadStatusChange(loadStatus: $0, audioKey: chat.audioKey)
            }
        case .loading:
            audio.setLoadStatusListener { [weak self] in
                guard let me = self else { return }
                me.handleLoadStatusChange(loadStatus: $0, audioKey: chat.audioKey)
            }
        case .loaded(let data):
            playAudio(data: data)
            removeFromAudioQueue(audioKey: chat.audioKey)
        case .failed:
            removeFromAudioQueue(audioKey: chat.audioKey)
        }
    }
    // swiftlint:enable cyclomatic_complexity

    func preloadFromAudioQueue() {
        let firstLoading = audioQueue.filter({ $0.loadStatus == .loading }).first
        if let firstLoading = firstLoading {
            logPreload("Audio load is in progress for \(firstLoading.audioKey).")
            return
        }
        guard let firstNotLoaded = audioQueue.filter({ $0.loadStatus == .notLoaded }).first else {
            logPreload("Seems no audio needs to request load.")
            return
        }
        logPreload("Calling load for \(firstNotLoaded.audioKey)")
        firstNotLoaded.startLoad(
            speedScale: voicevoxSpeed,
            volumeScale: voiceVolume.asVoicevoxVolumeScale,
            speaker: voiceSpeaker)
    }

    func handleLoadStatusChange(loadStatus: VoicevoxAudio.LoadStatus, audioKey: String) {
        switch loadStatus {
        case .notLoaded:
            break
        case .loading:
            requestingAudioLoad = true
        case .loaded(let data):
            requestingAudioLoad = false
            playAudio(data: data)
            removeFromAudioQueue(audioKey: audioKey)
        case .failed:
            requestingAudioLoad = false
            removeFromAudioQueue(audioKey: audioKey)
        }
    }

    func removeFromAudioQueue(audioKey: String) {
        audioQueue = audioQueue.filter({ $0.audioKey != audioKey })
    }

    func refreshChatQueueIfQueuedTooMuch() -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if refreshChatQueueThreshold < chatQueue.count {
            chatQueue.forEach {
                self.removeFromAudioQueue(audioKey: $0.audioKey)
            }
            chatQueue.removeAll()
            return true
        }

        return false
    }

    // TODO: block ４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４
    // define as 'internal' for test
    func isAcceptableComment(_ comment: String) -> Bool {
        return comment.count < 100 &&
            emojiRegexp.matchCount(in: comment) < 5 &&
            lineBreakRegexp.matchCount(in: comment) < 3 &&
            repeatedKanjiRegexp.matchCount(in: comment) == 0
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

private extension SpeechManager {
    func configure() {
        let volume = UserDefaults.standard.integer(forKey: Parameters.commentSpeechVolume)
        setVoiceVolume(volume)
        let speakerId = UserDefaults.standard.integer(forKey: Parameters.commentSpeechVoicevoxSpeaker)
        setVoiceSpeaker(speakerId)
    }

    func adjustedVoiceSpeed(currentCommentLength current: Int, remainingCommentLength remaining: Int, currentVoiceSpeed: Float) -> Float {
        let total = current + remaining
        var candidateSpeed = voiceSpeedMap[0].speed
        for (commentLengthRange, speed) in voiceSpeedMap {
            if commentLengthRange.contains(total) {
                candidateSpeed = speed
                break
            }
        }
        let adjusted = remaining == 0 ? candidateSpeed : max(currentVoiceSpeed, candidateSpeed)
        // log.debug("current: \(current) remaining: \(remaining) total: \(total) candidate: \(candidateSpeed) adjusted: \(adjusted)")
        return adjusted
    }

    func speak(comment: String, speed: Float, volume: Float) {
        guard #available(macOS 10.14, *) else { return }
        let utterance = AVSpeechUtterance.init(string: comment)
        utterance.rate = speed
        utterance.volume = volume
        let voice = AVSpeechSynthesisVoice.init(language: "ja-JP")
        utterance.voice = voice
        _Synthesizer.shared.synthesizer.speak(utterance)
    }

    func adjustedVoicevoxSpeed(currentCommentLength current: Int, remainingCommentLength remaining: Int, currentVoiceSpeed: Float) -> Float {
        let total = current + remaining
        var candidateSpeed = voicevoxSpeedMap[0].speed
        for (commentLengthRange, speed) in voicevoxSpeedMap {
            if commentLengthRange.contains(total) {
                candidateSpeed = speed
                break
            }
        }
        let adjusted = remaining == 0 ? candidateSpeed : max(currentVoiceSpeed, candidateSpeed)
        // log.debug("current: \(current) remaining: \(remaining) total: \(total) candidate: \(candidateSpeed) adjusted: \(adjusted)")
        return adjusted
    }

    func playAudio(data: Data) {
        guard let player = try? AVAudioPlayer(data: data) else { return }
        self.player = player
        self.player.play()
    }
}

private extension NSRegularExpression {
    func matchCount(in text: String) -> Int {
        return numberOfMatches(in: text, options: [], range: NSRange(0..<text.count))
    }
}

private extension Array where Element == VoicevoxAudio {
    func firstFilter(audioKey: String) -> VoicevoxAudio? {
        return self.filter { $0.audioKey == audioKey }.first
    }
}

private extension Chat {
    var audioKey: String { "\(no)-\(dateUsec)-\(userId)" }
}

private extension Int {
    var asVoicevoxVolumeScale: Float { Float(self) / 100 }
}

private extension SpeechManager {
    func logAudioQueue() {
        let updated = _chatQueueCount != chatQueue.count
            || _audioQueueCount != audioQueue.count
            || _voiceVoxSpeed != voiceSpeaker

        if updated {
            log.debug("chatQueue: \(chatQueue.count), audioQueue: \(audioQueue.count), speed: \(voicevoxSpeed)")
        }

        _chatQueueCount = chatQueue.count
        _audioQueueCount = audioQueue.count
        _voiceVoxSpeed = voiceSpeaker
    }

    func logPreload(_ message: String) {
        let updated = _preloadMessage != message

        if updated {
            log.debug(message)
        }

        _preloadMessage = message
    }
}
