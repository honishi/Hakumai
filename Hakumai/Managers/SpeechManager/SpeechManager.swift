//
//  SpeechManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AVFoundation

private let dequeuSpeechQueueInterval: TimeInterval = 0.25
private let maxSpeechCountForRefresh = 30
private let maxRecentSpeechTextsCount = 50
private let maxPreloadAudioCount = 5
private let maxCommentLengthSkippingDuplicate = 10

// https://stackoverflow.com/a/38409026/13220031
// See unicode list at https://0g0.org/ or https://0g0.org/unicode-list/
// See unicode search at https://www.marbacka.net/msearch/tool.php#chr2enc
private let emojiPattern = "[\\U0001F000-\\U0001F9FF]"
private let lineBreakPattern = "\n"
// https://stackoverflow.com/a/1660739/13220031
// private let repeatedCharPattern = "(.)\\1{9,}"
// https://so-zou.jp/software/tech/programming/tech/regular-expression/meta-character/variable-width-encoding.htm#no1
private let repeatedKanjiPattern = "(\\p{Han})\\1{9,}"
private let repeatedNumberPattern = "[1234567890１２３４５６７８９０]{9,}"

private let cleanCommentPatterns = [
    ("https?://[\\w!?/+\\-_~;.,*&@#$%()'\\[\\]=]+", " URL "),
    ("(w|W|ｗ|Ｗ){2,}", " わらわら"),
    ("(w|W|ｗ|Ｗ)$", " わら"),
    ("(8|８){3,}", "ぱちぱち"),
    ("ニコ生(?!放送)", "ニコなま"),
    ("初見", "しょけん"),
    // Removing Kao-moji.
    // https://qiita.com/sanma_ow/items/b49b39ad5699bbcac0e9
    ("\\([^あ-ん\\u30A1-\\u30F4\\u2E80-\\u2FDF\\u3005-\\u3007\\u3400-\\u4DBF\\u4E00-\\u9FFF\\uF900-\\uFAFF\\U00020000-\\U0002EBEF]+?\\)", ""),
    // At last, remove leading, trailing and middle white spaces.
    // https://stackoverflow.com/a/19020103/13220031
    ("(^\\s+|\\s+$|\\s+(?=\\s))", "")
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
        case duplicate, long, manyEmoji, manyLines, manySameKanji, manyNumber
    }

    struct Speech {
        let text: String
        let audioLoader: AudioLoaderType
    }

    // MARK: - Properties
    private var speechQueue: [Speech] = []
    private var activeSpeech: Speech?
    private var allSpeeches: [Speech] { ([activeSpeech] + speechQueue).compactMap { $0 } }
    private var recentSpeechTexts: [String] = []
    private var trashQueue: [Speech] = []

    // min(normal): 1.0, fast: 2.0
    private var voiceSpeed = VoiceSpeed.default
    // min: 0, max(normal): 100
    private var voiceVolume = VoiceVolume.default
    private var voiceSpeaker = 0
    private var timer: Timer?

    // swiftlint:disable force_try
    private let emojiRegexp = try! NSRegularExpression(pattern: emojiPattern, options: [])
    private let lineBreakRegexp = try! NSRegularExpression(pattern: lineBreakPattern, options: [])
    private let repeatedKanjiRegexp = try! NSRegularExpression(pattern: repeatedKanjiPattern, options: [])
    private let repeatedNumberRegexp = try! NSRegularExpression(pattern: repeatedNumberPattern, options: [])
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
                timeInterval: dequeuSpeechQueueInterval,
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
        trashQueue.removeAll()
        log.debug("stopped speech manager.")
    }

    // min/max: 0-100
    func setVoiceVolume(_ volume: Int) {
        voiceVolume = VoiceVolume(volume)
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
                    + "Sp:[\(voiceSpeed)/\(voiceSpeed.asVoicevox)/\(voiceSpeed.asAVSpeechSynthesizer)] "
                    + "Tx:[\(speech.text)]")
        switch speech.audioLoader.state {
        case .notLoaded:
            speech.audioLoader.startLoad(
                speedScale: voiceSpeed.asVoicevox,
                volumeScale: voiceVolume.asVoicevox,
                speaker: voiceSpeaker)
            fallthrough
        case .loading:
            speech.audioLoader.setStateChangeListener { [weak self] in
                log.debug("Got status update: [\($0)]  [\(speech.text)]")
                self?.listenStateChangeForExclusiveAudioLoad(state: $0, speech: speech)
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

    // define as 'internal' for test
    func preCheckComment(_ comment: String) -> CommentPreCheckResult {
        if comment.count > 100 {
            return .reject(.long)
        } else if emojiRegexp.matchCount(in: comment) > 5 {
            return .reject(.manyEmoji)
        } else if lineBreakRegexp.matchCount(in: comment) > 3 {
            return .reject(.manyLines)
        } else if repeatedKanjiRegexp.matchCount(in: comment) > 0 {
            return .reject(.manySameKanji)
        } else if repeatedNumberRegexp.matchCount(in: comment) > 0 {
            return .reject(.manyNumber)
        }

        let isUniqueComment = recentSpeechTexts.filter { $0 == comment }.isEmpty
        let isShortComment = comment.count <= maxCommentLengthSkippingDuplicate
        if isUniqueComment || isShortComment {
            return .accept
        }
        return .reject(.duplicate)
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
        switch preCheckComment(text) {
        case .accept:
            return text
        case .reject(let reason):
            switch reason {
            case .duplicate:
                return speechTextDuplicate
            case .long, .manyEmoji, .manyLines, .manySameKanji, .manyNumber:
                return speechTextSkip
            }
        }
    }

    func appendToSpeechQueue(text: String) {
        let speech = Speech(
            text: text,
            audioLoader: AudioLoader(
                text: text,
                maxTextLengthForEnablingCache: maxCommentLengthSkippingDuplicate
            )
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
        trashQueue = speechQueue
        speechQueue.removeAll()
        voiceSpeed = VoiceSpeed.default
        appendToSpeechQueue(text: speechTextRefresh)
    }

    func preloadAudioIfAvailable() {
        if let firstLoadingInTrash = trashQueue.firstAudioLoader(state: .loading) {
            logPreloadStatus("Audio load in trash q is in progress for [\(firstLoadingInTrash.text)].")
            return
        }
        if let firstLoading = allSpeeches.firstAudioLoader(state: .loading) {
            logPreloadStatus("Audio load is in progress for [\(firstLoading.text)].")
            return
        }
        if allSpeeches.loadedAudioLoadersCount > maxPreloadAudioCount {
            logPreloadStatus("Already preloaded enough audio.")
            return
        }
        if let firstNotLoaded = allSpeeches.firstAudioLoader(state: .notLoaded) {
            logPreloadStatus("Requesting load for [\(firstNotLoaded.text)].")
            firstNotLoaded.startLoad(
                speedScale: voiceSpeed.asVoicevox,
                volumeScale: voiceVolume.asVoicevox,
                speaker: voiceSpeaker)
            return
        }
        logPreloadStatus("Seems no audio needs to request load.")
    }

    func adjustedVoiceSpeed(currentCommentLength current: Int, remainingCommentLength remaining: Int, currentVoiceSpeed: VoiceSpeed) -> VoiceSpeed {
        let total = Float(current) + Float(remaining)
        let averageCommentLength: Float = 20
        let normalCommentCount: Float = 5
        let candidateSpeed = max(min(total / averageCommentLength / normalCommentCount, 2), 1)
        let adjusted = remaining == 0 ? candidateSpeed : max(currentVoiceSpeed.value, candidateSpeed)
        // log.debug("current: \(current) remaining: \(remaining) total: \(total) candidate: \(candidateSpeed) adjusted: \(adjusted)")
        return VoiceSpeed(adjusted)
    }

    func listenStateChangeForExclusiveAudioLoad(state: AudioLoaderState, speech: Speech) {
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
                speed: voiceSpeed.asAVSpeechSynthesizer,
                volume: voiceVolume.asAVSpeechSynthesizer)
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

private struct VoiceSpeed: CustomStringConvertible {
    // min~max: 1.0~2.0
    let value: Float
    var description: String { String(value) }

    static var `default`: VoiceSpeed { VoiceSpeed(1) }

    init(_ value: Float) {
        self.value =  max(min(value, 2), 1)
    }
}

private extension VoiceSpeed {
    // min~max: 1.0~2.0 -> 1.0~1.7
    var asVoicevox: Float { 1.0 + (value - 1) * 0.7 }

    // min~max: 1.0~2.0 -> 0.5~0.75
    var asAVSpeechSynthesizer: Float { 0.5 + (value - 1) * 0.25 }
}

private struct VoiceVolume: CustomStringConvertible {
    // min~max: 0~100
    let value: Int
    var description: String { String(value) }

    static var `default`: VoiceVolume { VoiceVolume(100) }

    init(_ value: Int) {
        self.value = max(min(value, 100), 0)
    }
}

private extension VoiceVolume {
    // min~max: 0~100 -> 0.0~1.0
    var asVoicevox: Float { Float(value) / 100.0 }

    // min~max: 0~100 -> 0.0~1.0
    var asAVSpeechSynthesizer: Float { Float(value) / 100.0 }
}

private extension NSRegularExpression {
    func matchCount(in text: String) -> Int {
        return numberOfMatches(in: text, options: [], range: NSRange(0..<text.count))
    }
}

private extension Array where Element == SpeechManager.Speech {
    func audioLoaders(state: AudioLoaderState) -> [AudioLoaderType] {
        return map { $0.audioLoader }.filter { $0.state == state }
    }

    func firstAudioLoader(state: AudioLoaderState) -> AudioLoaderType? {
        return audioLoaders(state: state).first
    }

    var loadedAudioLoadersCount: Int {
        map { $0.audioLoader }
            .filter {
                if case .loaded = $0.state { return true }
                return false
            }.count
    }
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
