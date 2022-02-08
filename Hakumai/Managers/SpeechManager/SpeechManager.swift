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
private let refreshChatQueueThreshold = 30
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

@available(macOS 10.14, *)
final class _Synthesizer {
    static let shared = _Synthesizer()
    let synthesizer = AVSpeechSynthesizer()
}

final class SpeechManager: NSObject {
    // MARK: - Types
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
    private var waitingAudioLoadCompletion = false

    // Debug: for logger
    private var _speechQueueCount = -1
    private var _voiceSpeed = -1
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
        guard isAcceptableComment(chat.comment) else { return }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let text = cleanComment(from: chat.comment)
        let speech = Speech(
            text: text,
            audioLoader: AudioLoader(text: text)
        )
        speechQueue.append(speech)
        // Do not call `preloadAudioIfAvailable()` here, since it will cause dequeue conflict.

        recentSpeechTexts.append(text)
        if recentSpeechTexts.count > maxRecentSpeechTextsCount {
            recentSpeechTexts.remove(at: 0)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    @objc func dequeue(_ timer: Timer?) {
        guard #available(macOS 10.14, *) else { return }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        logAudioQueue()
        preloadAudioIfAvailable()

        // log.debug("\(requestingAudioLoad), \(player.isPlaying)")
        guard !waitingAudioLoadCompletion else { return }

        let isSpeaking = player.isPlaying || _Synthesizer.shared.synthesizer.isSpeaking
        guard !isSpeaking else { return }

        guard !speechQueue.isEmpty else { return }
        activeSpeech = speechQueue.removeFirst()

        guard let speech = activeSpeech else { return }

        let isUniqueComment = recentSpeechTexts.filter { $0 == speech.text }.count == 1
        let isShortComment = speech.text.count < 10
        guard isUniqueComment || isShortComment else {
            log.debug("skip duplicate speech comment. [\(speech.text)]")
            return
        }

        voiceSpeed = adjustedVoiceSpeed(
            currentCommentLength: speech.text.count,
            remainingCommentLength: speechQueue.map { $0.text.count }.reduce(0, +),
            currentVoiceSpeed: voiceSpeed)

        log.debug("\(speech.audioLoader.state) "
                    + "[\(voiceSpeed)/\(voiceSpeed.asVoicevoxSpeedScale)/\(voiceSpeed.asAVSpeechSynthesizerSpeedRate)] "
                    + "[\(speech.text)]")
        switch speech.audioLoader.state {
        case .notLoaded:
            speech.audioLoader.startLoad(
                speedScale: voiceSpeed.asVoicevoxSpeedScale,
                volumeScale: voiceVolume.asVoicevoxVolumeScale,
                speaker: voiceSpeaker)
            speech.audioLoader.setLoadStatusListener { [weak self] in
                guard let me = self else { return }
                me.handleLoadStatusChange(loadStatus: $0)
            }
        case .loading:
            speech.audioLoader.setLoadStatusListener { [weak self] in
                guard let me = self else { return }
                me.handleLoadStatusChange(loadStatus: $0)
            }
        case .loaded(let data):
            playAudio(data: data)
        case .failed:
            speakOnAVSpeechSynthesizer(
                comment: speech.text,
                speed: voiceSpeed.asAVSpeechSynthesizerSpeedRate,
                volume: voiceVolume.asAVSpeechSynthesizerVolume)
        }
    }
    // swiftlint:enable cyclomatic_complexity

    func preloadAudioIfAvailable() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        let audioLoaders = allSpeeches.map { $0.audioLoader }
        let firstLoading = audioLoaders.filter({ $0.state == .loading }).first
        if let firstLoading = firstLoading {
            logPreload("Audio load is in progress for \(firstLoading.text).")
            return
        }
        guard let firstNotLoaded = audioLoaders.filter({ $0.state == .notLoaded }).first else {
            logPreload("Seems no audio needs to request load.")
            return
        }
        logPreload("Requesting load for \(firstNotLoaded.text)")
        firstNotLoaded.startLoad(
            speedScale: voiceSpeed.asVoicevoxSpeedScale,
            volumeScale: voiceVolume.asVoicevoxVolumeScale,
            speaker: voiceSpeaker)
    }

    func handleLoadStatusChange(loadStatus: AudioLoader.LoadState) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        switch loadStatus {
        case .notLoaded:
            break
        case .loading:
            waitingAudioLoadCompletion = true
        case .loaded(let data):
            waitingAudioLoadCompletion = false
            playAudio(data: data)
        case .failed:
            waitingAudioLoadCompletion = false
        }
    }

    func refreshChatQueueIfQueuedTooMuch() -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if refreshChatQueueThreshold < speechQueue.count {
            speechQueue.removeAll()
            appendSystemSpeech("コメントが多すぎるため、読み上げをリセットしました")
            return true
        }

        return false
    }

    func appendSystemSpeech(_ text: String) {
        let speech = Speech(
            text: text,
            audioLoader: AudioLoader(text: text)
        )
        speechQueue.append(speech)
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
        let total = Float(current) + Float(remaining)
        let averageCommentLength: Float = 20
        let normalCommentCount: Float = 5
        let candidateSpeed = max(min(total / averageCommentLength / normalCommentCount, 2), 1)
        let adjusted = remaining == 0 ? candidateSpeed : max(currentVoiceSpeed, candidateSpeed)
        // log.debug("current: \(current) remaining: \(remaining) total: \(total) candidate: \(candidateSpeed) adjusted: \(adjusted)")
        return adjusted
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
    // min~max: 1.0~2.0 -> 1.0~1.8
    var asVoicevoxSpeedScale: Float { 1.0 + (self - 1) * 0.8 }

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
        let updated = _speechQueueCount != speechQueue.count
            || _voiceSpeed != voiceSpeaker

        if updated {
            log.debug("speechQueue: \(speechQueue.count), speed: \(voiceSpeed)")
        }

        _speechQueueCount = speechQueue.count
        _voiceSpeed = voiceSpeaker
    }

    func logPreload(_ message: String) {
        let updated = _preloadMessage != message

        if updated {
            log.debug(message)
        }

        _preloadMessage = message
    }
}
