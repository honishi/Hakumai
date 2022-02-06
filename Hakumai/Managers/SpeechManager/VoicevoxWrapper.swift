//
//  VoicevoxWrapper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/06.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

protocol VoicevoxWrapperType {
    func requestAudio(text: String, speedScale: Float, speaker: Int, completion: @escaping AudioRequestCompletion)
}

typealias AudioRequestCompletion = (Result<Data, VoicevoxWrapperError>) -> Void

enum VoicevoxWrapperError: Error {
    case `internal`
}

private let voicevoxUrl = "http://localhost:50021"

final class VoicevoxWrapper: VoicevoxWrapperType {
    struct AudioConfiguration {
        let text: String
        let speedScale: Float
        let speaker: Int
    }
}

extension VoicevoxWrapper {
    func requestAudio(text: String, speedScale: Float, speaker: Int, completion: @escaping AudioRequestCompletion) {
        let config = AudioConfiguration(
            text: text,
            speedScale: speedScale,
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
            log.debug(dictionary)
            dictionary["speedScale"] = config.speedScale
            guard let _data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else {
                log.debug("Failed to make audio query data. \(data)")
                completion(Result.failure(.internal))
                return
            }
            if let string = String(bytes: _data, encoding: .utf8) {
                log.debug(string)
            }
            requestSynthesis(data: _data, config: config, completion: completion)
        case .failure(let error):
            log.error(error)
            completion(Result.failure(.internal))
        }
    }

    func requestSynthesis(data: Data, config: AudioConfiguration, completion: @escaping AudioRequestCompletion) {
        let urlString = voicevoxUrl + "/synthesis?speaker=\(config.speaker)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .post
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        AF.request(request)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData { [weak self] in
                self?.handleSynthesisResponse($0, completion: completion)
            }
    }

    func handleSynthesisResponse(_ response: AFDataResponse<Data>, completion: @escaping AudioRequestCompletion) {
        switch response.result {
        case .success(let data):
            log.debug(data)
            completion(Result.success(data))
        case .failure(let error):
            log.error(error)
            completion(Result.failure(VoicevoxWrapperError.internal))
        }
    }
}

private extension String {
    var escapsed: String { URLEncoding.default.escape(self) }
}
