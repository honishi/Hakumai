//
//  VoicevoxAudio.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/06.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let maxRetryCount = 3

final class VoicevoxAudio {
    enum LoadStatus: Equatable {
        case notLoaded, loading, loaded(Data), failed
    }
    typealias Listener = ((LoadStatus) -> Void)

    private(set) var loadStatus: LoadStatus = .notLoaded

    let audioKey: String

    private let comment: String
    private let speedScale: Float
    private let speaker: Int

    private var listener: Listener?
    private let voicevoxWrapper: VoicevoxWrapperType = VoicevoxWrapper()
    private var retryCount = 0

    init(audioKey: String, comment: String, speedScale: Float, speaker: Int) {
        self.audioKey = audioKey
        self.comment = comment
        self.speedScale = speedScale
        self.speaker = speaker
    }

    func startLoad() {
        loadStatus = .loading
        voicevoxWrapper.requestAudio(
            text: comment,
            speedScale: speedScale,
            speaker: speaker
        ) { [weak self] in
            guard let me = self else { return }
            var shouldRetry = false
            switch $0 {
            case .success(let data):
                log.debug("loaded: \(me.audioKey), \(data), \(me.comment)")
                me.loadStatus = .loaded(data)
            case .failure(let error):
                log.error("failed: \(me.audioKey), \(error), \(me.comment)")
                me.loadStatus = .failed
                me.retryCount += 1
                shouldRetry = me.retryCount <= maxRetryCount
            }
            me.listener?(me.loadStatus)
            if shouldRetry {
                me.startLoad()
            }
        }
    }

    func setLoadStatusListener(_ listener: Listener?) {
        self.listener = listener
        self.listener?(loadStatus)
    }
}
