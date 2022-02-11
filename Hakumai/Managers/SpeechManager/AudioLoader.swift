//
//  AudioLoader.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/06.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol AudioLoaderType {
    var text: String { get }
    var state: AudioLoaderState { get }

    func startLoad(speedScale: Float, volumeScale: Float, speaker: Int)
    func setStateChangeListener(_ listener: AudioLoaderStateChangeListener?)
}

typealias AudioLoaderStateChangeListener = ((AudioLoaderState) -> Void)

enum AudioLoaderState: Equatable {
    case notLoaded, loading, loaded(Data), failed
}

final class AudioLoader: AudioLoaderType {
    let text: String
    private(set) var state: AudioLoaderState = .notLoaded

    private let voicevoxWrapper: VoicevoxWrapperType
    private let audioCacher: AudioCacherType
    private var listener: AudioLoaderStateChangeListener?

    init(text: String,
         voicevoxWrapper: VoicevoxWrapperType = VoicevoxWrapper(),
         audioCacher: AudioCacherType = AudioCacher.shared
    ) {
        self.text = text
        self.voicevoxWrapper = voicevoxWrapper
        self.audioCacher = audioCacher
    }

    deinit { log.debug("") }

    func startLoad(speedScale: Float, volumeScale: Float, speaker: Int) {
        state = .loading
        listener?(state)

        if let cached = audioCacher.get(
            speedScale: speedScale,
            volumeScale: volumeScale,
            speaker: speaker,
            text: text
        ) {
            log.debug("Found audio on cache: [\(text)] [\(cached)]")
            state = .loaded(cached)
            listener?(state)
            return
        }

        voicevoxWrapper.requestAudio(
            text: text,
            speedScale: speedScale,
            volumeScale: volumeScale,
            speaker: speaker
        ) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let data):
                log.debug("loaded: \(data), \(me.text)")
                me.state = .loaded(data)
                me.cacheDataIfConditionMet(
                    speedScale: speedScale, volumeScale: volumeScale,
                    speaker: speaker, text: me.text, data: data)
            case .failure(let error):
                log.error("failed: \(error), \(me.text)")
                me.state = .failed
            }
            me.listener?(me.state)
        }
    }

    func setStateChangeListener(_ listener: AudioLoaderStateChangeListener?) {
        self.listener = listener
        self.listener?(state)
    }
}

private extension AudioLoader {
    func cacheDataIfConditionMet(speedScale: Float, volumeScale: Float, speaker: Int, text: String, data: Data) {
        let isShortComment = text.count <= maxCommentLengthSkippingDuplicate
        guard isShortComment else {
            log.debug("Skip caching audio data. (long) [\(text)/\(data)]")
            return
        }
        audioCacher.set(
            speedScale: speedScale, volumeScale: volumeScale,
            speaker: speaker, text: text, data: data)
        log.debug("Cached audio data. [\(text)/\(data)]")
    }
}
