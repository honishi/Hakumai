//
//  VoicevoixAudio.swift
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
    private let speedScale: Float
    private let speaker: Int

    private var listener: Listener?
    private let voicevoxWrapper: VoicevoxWrapperType = VoicevoxWrapper()

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
            switch $0 {
            case .success(let data):
                log.debug(data)
                me.loadStatus = .loaded(data)
            case .failure(let error):
                log.error(error)
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
