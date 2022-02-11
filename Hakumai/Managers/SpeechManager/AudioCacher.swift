//
//  AudioCacher.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/11.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol AudioCacherType {
    func get(speedScale: Float, volumeScale: Float, speaker: Int, text: String) -> Data?
    func set(speedScale: Float, volumeScale: Float, speaker: Int, text: String, data: Data)
}

private let cacheCountLimit = 100

final class AudioCacher: NSObject, AudioCacherType {
    static let shared = AudioCacher()

    private let cache = NSCache<NSString, AudioData>()

    override init() {
        super.init()
        cache.delegate = self
        cache.countLimit = cacheCountLimit
    }

    deinit { log.debug("") }

    func get(speedScale: Float, volumeScale: Float, speaker: Int, text: String) -> Data? {
        let key = cacheKey(speedScale, volumeScale, speaker, text)
        return cache.object(forKey: key)?.data
    }

    func set(speedScale: Float, volumeScale: Float, speaker: Int, text: String, data: Data) {
        let key = cacheKey(speedScale, volumeScale, speaker, text)
        let object = AudioData(
            speedScale: speedScale,
            volumeScale: volumeScale,
            speaker: speaker,
            text: text,
            data: data)
        cache.setObject(object, forKey: key)
    }
}

extension AudioCacher: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        log.debug("Audio cache evicted: \(obj)")
    }
}

private extension AudioCacher {
    func cacheKey(_ speedScale: Float, _ volumeScale: Float, _ speaker: Int, _ text: String) -> NSString {
        return "\(speedScale):\(volumeScale):\(speaker):\(text.hashValue)" as NSString
    }
}

private class AudioData: CustomStringConvertible {
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
