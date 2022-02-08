//
//  VoicevoxWrapper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/06.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

// TODO: to static
protocol VoicevoxWrapperType {
    func requestSpeakers(completion: @escaping SpeakersRequestCompletion)
    func requestAudio(text: String, speedScale: Float, volumeScale: Float, speaker: Int, completion: @escaping AudioRequestCompletion)
}

typealias SpeakersRequestCompletion = (Result<[VoicevoxSpeaker], VoicevoxWrapperError>) -> Void
typealias AudioRequestCompletion = (Result<Data, VoicevoxWrapperError>) -> Void

struct VoicevoxSpeaker {
    let speakerId: Int
    let name: String
}

enum VoicevoxWrapperError: Error {
    case `internal`
}

private let httpHeaderKeyContentType = "Content-Type"
private let httpHeaderValueApplicationJson = "application/json"
private let voicevoxUrl = "http://localhost:50021"

final class VoicevoxWrapper: VoicevoxWrapperType {
    struct AudioConfiguration {
        let text: String
        let speedScale: Float
        let volumeScale: Float
        let speaker: Int
    }
}

extension VoicevoxWrapper {
    func requestSpeakers(completion: @escaping SpeakersRequestCompletion) {
        let urlString = voicevoxUrl + "/speakers"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .get
        request.setValue(httpHeaderValueApplicationJson, forHTTPHeaderField: httpHeaderKeyContentType)
        AF.request(request)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData {
                switch $0.result {
                case .success(let data):
                    guard let decoded = try? JSONDecoder().decode([VoicevoxSpeakerResponse].self, from: data) else {
                        completion(Result.failure(.internal))
                        return
                    }
                    completion(Result.success(decoded.toVoicevoxSpeakers()))
                case .failure(let error):
                    log.error(error)
                    completion(Result.failure(.internal))
                }
            }
    }

    func requestAudio(text: String, speedScale: Float, volumeScale: Float, speaker: Int, completion: @escaping AudioRequestCompletion) {
        let config = AudioConfiguration(
            text: text,
            speedScale: speedScale,
            volumeScale: volumeScale,
            speaker: speaker
        )
        requestAudioQuery(config: config, completion: completion)
    }
}

private extension VoicevoxWrapper {
    func requestAudioQuery(config: AudioConfiguration, completion: @escaping AudioRequestCompletion) {
        log.debug("\(config.text), \(config.speedScale), \(config.speaker)")
        let urlString = voicevoxUrl + "/audio_query?text=\(config.text.escapsed)&speaker=\(config.speaker)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .post
        AF.request(request)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData { [weak self] in
                self?.handleAudioQueryResponse($0, config: config, completion: completion)
            }
    }

    func handleAudioQueryResponse(_ response: AFDataResponse<Data>, config: AudioConfiguration, completion: @escaping AudioRequestCompletion) {
        switch response.result {
        case .success(let data):
            guard var dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                log.debug("Failed to parse audio query data. \(data)")
                completion(Result.failure(.internal))
                return
            }
            // log.debug(dictionary)
            dictionary["speedScale"] = config.speedScale
            dictionary["volumeScale"] = config.volumeScale
            guard let _data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else {
                log.debug("Failed to make audio query data. \(data)")
                completion(Result.failure(.internal))
                return
            }
            if let string = String(bytes: _data, encoding: .utf8) {
                // log.debug(string)
            }
            requestSynthesis(data: _data, config: config, completion: completion)
        case .failure(let error):
            log.error("[\(config.text)] \(error)")
            completion(Result.failure(.internal))
        }
    }

    func requestSynthesis(data: Data, config: AudioConfiguration, completion: @escaping AudioRequestCompletion) {
        let urlString = voicevoxUrl + "/synthesis?speaker=\(config.speaker)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .post
        request.setValue(httpHeaderValueApplicationJson, forHTTPHeaderField: httpHeaderKeyContentType)
        request.httpBody = data
        AF.request(request)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData { [weak self] in
                self?.handleSynthesisResponse($0, config: config, completion: completion)
            }
    }

    func handleSynthesisResponse(_ response: AFDataResponse<Data>, config: AudioConfiguration, completion: @escaping AudioRequestCompletion) {
        switch response.result {
        case .success(let data):
            log.debug("[\(config.text)] [\(data)]")
            completion(Result.success(data))
        case .failure(let error):
            log.error("[\(config.text)] \(error)")
            completion(Result.failure(VoicevoxWrapperError.internal))
        }
    }
}

private extension String {
    var escapsed: String { URLEncoding.default.escape(self) }
}

private extension Array where Element == VoicevoxSpeakerResponse {
    func toVoicevoxSpeakers() -> [VoicevoxSpeaker] {
        return map { response in
            response.styles.map {
                VoicevoxSpeaker(
                    speakerId: $0.id,
                    name: "\(response.name) - \($0.name) [\($0.id)]"
                )
            }
        }.flatMap { $0 }
    }
}
