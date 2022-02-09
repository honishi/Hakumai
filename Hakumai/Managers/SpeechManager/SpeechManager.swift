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
private let maxSpeechCountForRefresh = 30
private let maxRecentSpeechTextsCount = 50

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

private let speechTextSkip = "コメント省略"
private let speechTextDuplicate = "コメント重複"
private let speechTextRefresh = "読み上げリセット"

@available(macOS 10.14, *)
final class _Synthesizer {
    static let shared = _Synthesizer()
    let synthesizer = AVSpeechSynthesizer()
}

final class SpeechManager: NSObject {
    // MARK: - Types
    enum CommentPreCheckResult: Equatable {
        case accept
        case reject(PreCheckRejectReason)
    }

    enum PreCheckRejectReason: Equatable {
        case duplicate, tooLong, tooManyEmoji, tooManyLines, tooManySameKanji
    }

    struct Speech {
        let text: String
        let audioLoader: AudioLoader
    }

    // MARK: - Properties
    private var speechQueue: [Speech] = []
    private var activeSpeech: Speech?
    private var allSpeeches: [Speech] { ([activeSpeech] + speechQueue).compactMap { $0 } }
    private var recentSpeechTexts: [String] = []

    // min(normal): 1.0, fast: 2.0
    private var voiceSpeed: Float = 1.0
    // min: 0, max(normal): 100
    private var voiceVolume = 100
    private var voiceSpeaker = 0
    private var timer: Timer?

    // swiftlint:disable force_try
    private let emojiRegexp = try! NSRegularExpression(pattern: emojiPattern, options: [])
    private let lineBreakRegexp = try! NSRegularExpression(pattern: lineBreakPattern, options: [])
    private let repeatedKanjiRegexp = try! NSRegularExpression(pattern: repeatedKanjiPattern, options: [])
    // swiftlint:enable force_try

    private var player: AVAudioPlayer = AVAudioPlayer()
    private var waitingExclusiveAudioLoadCompletion = false

    // Debug: for logger
    private var _previousSpeechQueueLogMessage = ""
    private var _previousPreloadStatusMessage = ""

    // MARK: - Object Lifecycle
    override init() {
        super.init()
        configure()
    }

    deinit { log.debug("") }
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
    }

    func stopManager() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        speechQueue.removeAll()
        recentSpeechTexts.removeAll()
        activeSpeech = nil
        log.debug("stopped speech manager.")
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

        let clean = cleanComment(from: chat.comment)
        let text = checkAndMakeText(clean)

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        appendToSpeechQueue(text: text)
        appendToRecentSpeechTexts(text)
        refreshSpeechQueueIfNeeded()
    }

    @objc func dequeue(_ timer: Timer?) {
        guard #available(macOS 10.14, *) else { return }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        logAudioQueue()
        preloadAudioIfAvailable()

        // log.debug("\(requestingAudioLoad), \(player.isPlaying)")
        guard !waitingExclusiveAudioLoadCompletion else { return }

        let isSpeaking = player.isPlaying || _Synthesizer.shared.synthesizer.isSpeaking
        guard !isSpeaking else { return }

        guard !speechQueue.isEmpty else { return }
        activeSpeech = speechQueue.removeFirst()

        guard let speech = activeSpeech else { return }

        voiceSpeed = adjustedVoiceSpeed(
            currentCommentLength: speech.text.count,
            remainingCommentLength: speechQueue.map { $0.text.count }.reduce(0, +),
            currentVoiceSpeed: voiceSpeed)

        log.debug("Q:[\(speechQueue.count)] "
                    + "Act:[\(speech.audioLoader.state)] "
                    + "Sp:[\(voiceSpeed)/\(voiceSpeed.asVoicevoxSpeedScale)/\(voiceSpeed.asAVSpeechSynthesizerSpeedRate)] "
                    + "Tx:[\(speech.text)]")
        switch speech.audioLoader.state {
        case .notLoaded:
            speech.audioLoader.startLoad(
                speedScale: voiceSpeed.asVoicevoxSpeedScale,
                volumeScale: voiceVolume.asVoicevoxVolumeScale,
                speaker: voiceSpeaker)
            fallthrough
        case .loading:
            speech.audioLoader.setListenerForExclusiveAudioLoad { [weak self] in
                log.debug("Got status update: [\($0)]  [\(speech.text)]")
                guard let me = self else { return }
                me.handleLoadStateChange($0, speech: speech)
            }
        case .loaded, .failed:
            break
        }
        playAudioIfLoadFinished(speech: speech)
    }

    // define as 'internal' for test
    func cleanComment(from comment: String) -> String {
        var cleaned = comment
        cleanCommentPatterns.forEach {
            cleaned = cleaned.stringByReplacingRegexp(pattern: $0.0, with: $0.1)
        }
        return cleaned
    }

    // TODO: block ４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４４
    // define as 'internal' for test
    func preChechComment(_ comment: String) -> CommentPreCheckResult {
        if comment.count > 100 {
            return .reject(.tooLong)
        } else if emojiRegexp.matchCount(in: comment) > 5 {
            return .reject(.tooManyEmoji)
        } else if lineBreakRegexp.matchCount(in: comment) > 3 {
            return .reject(.tooManyLines)
        } else if repeatedKanjiRegexp.matchCount(in: comment) > 0 {
            return .reject(.tooManySameKanji)
        }

        let isUniqueComment = recentSpeechTexts.filter { $0 == comment }.isEmpty
        let isShortComment = comment.count < 10
        if !isUniqueComment && !isShortComment {
            return .reject(.duplicate)
        }

        return .accept
    }
}

private extension SpeechManager {
    func configure() {
        let volume = UserDefaults.standard.integer(forKey: Parameters.commentSpeechVolume)
        setVoiceVolume(volume)
        let speakerId = UserDefaults.standard.integer(forKey: Parameters.commentSpeechVoicevoxSpeaker)
        setVoiceSpeaker(speakerId)
    }

    func checkAndMakeText(_ text: String) -> String {
        switch preChechComment(text) {
        case .accept:
            return text
        case .reject(let reason):
            switch reason {
            case .duplicate:
                return speechTextDuplicate
            case .tooLong, .tooManyEmoji, .tooManyLines, .tooManySameKanji:
                return speechTextSkip
            }
        }
    }

    func appendToSpeechQueue(text: String) {
        let speech = Speech(
            text: text,
            audioLoader: AudioLoader(text: text)
        )
        speechQueue.append(speech)
    }

    func appendToRecentSpeechTexts(_ text: String) {
        recentSpeechTexts.append(text)
        let isRecentSpeechTextsFull = recentSpeechTexts.count > maxRecentSpeechTextsCount
        guard isRecentSpeechTextsFull else { return }
        recentSpeechTexts.remove(at: 0)
    }

    func refreshSpeechQueueIfNeeded() {
        let tooManySpeechesInQueue = speechQueue.count > maxSpeechCountForRefresh
        guard tooManySpeechesInQueue else { return }
        speechQueue.removeAll()
        appendToSpeechQueue(text: speechTextRefresh)
    }

    func preloadAudioIfAvailable() {
        let allAudioLoaders = allSpeeches.map { $0.audioLoader }
        let firstLoading = allAudioLoaders.filter({ $0.state == .loading }).first
        if let firstLoading = firstLoading {
            logPreloadStatus("Audio load is in progress for \(firstLoading.text).")
            return
        }
        guard let firstNotLoaded = allAudioLoaders.filter({ $0.state == .notLoaded }).first else {
            logPreloadStatus("Seems no audio needs to request load.")
            return
        }
        logPreloadStatus("Requesting load for \(firstNotLoaded.text)")
        firstNotLoaded.startLoad(
            speedScale: voiceSpeed.asVoicevoxSpeedScale,
            volumeScale: voiceVolume.asVoicevoxVolumeScale,
            speaker: voiceSpeaker)
    }

    func adjustedVoiceSpeed(currentCommentLength current: Int, remainingCommentLength remaining: Int, currentVoiceSpeed: Float) -> Float {
        let total = Float(current) + Float(remaining)
        let averageCommentLength: Float = 20
        let normalCommentCount: Float = 5
        let candidateSpeed = max(min(total / averageCommentLength / normalCommentCount, 2), 1)
        let adjusted = remaining == 0 ? candidateSpeed : max(currentVoiceSpeed, candidateSpeed)
        // log.debug("current: \(current) remaining: \(remaining) total: \(total) candidate: \(candidateSpeed) adjusted: \(adjusted)")
        return adjusted
    }

    func handleLoadStateChange(_ state: AudioLoader.LoadState, speech: Speech) {
        switch state {
        case .notLoaded:
            break
        case .loading:
            waitingExclusiveAudioLoadCompletion = true
        case .loaded, .failed:
            waitingExclusiveAudioLoadCompletion = false
        }
        playAudioIfLoadFinished(speech: speech)
    }

    func playAudioIfLoadFinished(speech: Speech) {
        switch speech.audioLoader.state {
        case .notLoaded, .loading:
            break
        case .loaded(let data):
            playAudio(data: data)
        case .failed:
            speakOnAVSpeechSynthesizer(
                comment: speech.text,
                speed: voiceSpeed.asAVSpeechSynthesizerSpeedRate,
                volume: voiceVolume.asAVSpeechSynthesizerVolume)
        }
    }

    func speakOnAVSpeechSynthesizer(comment: String, speed: Float, volume: Float) {
        guard #available(macOS 10.14, *) else { return }
        let utterance = AVSpeechUtterance.init(string: comment)
        utterance.rate = speed
        utterance.volume = volume
        let voice = AVSpeechSynthesisVoice.init(language: "ja-JP")
        utterance.voice = voice
        _Synthesizer.shared.synthesizer.speak(utterance)
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

private extension Float {
    // min~max: 1.0~2.0 -> 1.0~1.7
    var asVoicevoxSpeedScale: Float { 1.0 + (self - 1) * 0.7 }

    // min~max: 1.0~2.0 -> 0.5~0.75
    var asAVSpeechSynthesizerSpeedRate: Float { 0.5 + (self - 1) * 0.25 }
}

private extension Int {
    // min~max: 0~100 -> 0.0~1.0
    var asVoicevoxVolumeScale: Float { Float(self) / 100 }

    // min~max: 0~100 -> 0.0~1.0
    var asAVSpeechSynthesizerVolume: Float { Float(self) / 100.0 }
}

private extension SpeechManager {
    func logAudioQueue() {
        let message = "speechQueueCount: \(speechQueue.count), speed: \(voiceSpeed)"
        if message != _previousSpeechQueueLogMessage {
            log.debug(message)
        }
        _previousSpeechQueueLogMessage = message
    }

    func logPreloadStatus(_ message: String) {
        if message != _previousPreloadStatusMessage {
            log.debug(message)
        }
        _previousPreloadStatusMessage = message
    }
}
