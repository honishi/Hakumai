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

    init(text: String) {
        self.text = text
    }

    func startLoad(speedScale: Float, volumeScale: Float, speaker: Int) {
        state = .loading
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
            case .failure(let error):
                log.error("failed: \(error), \(me.text)")
                me.state = .failed
            }
            me.listener?(me.state)
        }
    }

    func setLoadStatusListener(_ listener: Listener?) {
        self.listener = listener
        self.listener?(state)
    }
}
