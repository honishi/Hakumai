//
//  VoicevoxAudio.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/06.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class VoicevoxAudio {
    enum LoadStatus: Equatable {
        case notLoaded, loading, loaded(Data), failed
    }
    typealias Listener = ((LoadStatus) -> Void)

    private(set) var loadStatus: LoadStatus = .notLoaded

    let audioKey: String

    private let comment: String

    private var listener: Listener?
    private let voicevoxWrapper: VoicevoxWrapperType = VoicevoxWrapper()

    init(audioKey: String, comment: String) {
        self.audioKey = audioKey
        self.comment = comment
    }

    func startLoad(speedScale: Float, volumeScale: Float, speaker: Int) {
        loadStatus = .loading
        voicevoxWrapper.requestAudio(
            text: comment,
            speedScale: speedScale,
            volumeScale: volumeScale,
            speaker: speaker
        ) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let data):
                log.debug("loaded: \(me.audioKey), \(data), \(me.comment)")
                me.loadStatus = .loaded(data)
            case .failure(let error):
                log.error("failed: \(me.audioKey), \(error), \(me.comment)")
                me.loadStatus = .failed
            }
            me.listener?(me.loadStatus)
        }
    }

    func setLoadStatusListener(_ listener: Listener?) {
        self.listener = listener
        self.listener?(loadStatus)
    }
}
