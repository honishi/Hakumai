//
//  AudioLoader.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/06.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class AudioLoader {
    enum LoadState: Equatable {
        case notLoaded, loading, loaded(Data), failed
    }
    typealias Listener = ((LoadState) -> Void)

    private(set) var state: LoadState = .notLoaded

    let text: String

    private var listener: Listener?
    private let voicevoxWrapper: VoicevoxWrapperType = VoicevoxWrapper()
    private let cache = AudioCache.shared

    init(text: String) {
        self.text = text
    }

    deinit { log.debug("") }

    func startLoad(speedScale: Float, volumeScale: Float, speaker: Int) {
        state = .loading
        listener?(state)

        if let cached = cache.get(
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

    func setStateChangeListener(_ listener: Listener?) {
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
        cache.set(
            speedScale: speedScale, volumeScale: volumeScale,
            speaker: speaker, text: text, data: data)
        log.debug("Cached audio data. [\(text)/\(data)]")
    }
}

private class AudioCache: NSObject {
    class DataWrapper: CustomStringConvertible {
        let speedScale: Float
        let volumeScale: Float
        let speaker: Int
        let text: String
        let data: Data

        var description: String { "\(speedScale)/\(volumeScale)/\(speaker)/\(text)/\(data)"}

        init(speedScale: Float, volumeScale: Float, speaker: Int, text: String, data: Data) {
            self.speedScale = speedScale
            self.volumeScale = volumeScale
            self.speaker = speaker
            self.text = text
            self.data = data
        }

        deinit { log.debug("") }
    }

    static let shared = AudioCache()

    private let cache = NSCache<NSString, DataWrapper>()

    override init() {
        super.init()
        cache.delegate = self
        cache.countLimit = 100
    }

    deinit { log.debug("") }

    func get(speedScale: Float, volumeScale: Float, speaker: Int, text: String) -> Data? {
        let key = cacheKey(speedScale, volumeScale, speaker, text)
        return cache.object(forKey: key)?.data
    }

    func set(speedScale: Float, volumeScale: Float, speaker: Int, text: String, data: Data) {
        let key = cacheKey(speedScale, volumeScale, speaker, text)
        let object = DataWrapper(
            speedScale: speedScale,
            volumeScale: volumeScale,
            speaker: speaker,
            text: text,
            data: data)
        cache.setObject(object, forKey: key)
    }
}

extension AudioCache: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        log.debug("Audio cache evicted: \(obj)")
    }
}

private extension AudioCache {
    func cacheKey(_ speedScale: Float, _ volumeScale: Float, _ speaker: Int, _ text: String) -> NSString {
        return "\(speedScale):\(volumeScale):\(speaker):\(text.hashValue)" as NSString
    }
}
