//
//  VoicevoxWrapper.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/06.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

// XXX: Make the following functions static.
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
    // VOICEVOX app is not available.
    case couldNotConnect
    // VOICEVOX app is available and connected but connection has been lost.
    case lostConnection
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

    deinit { log.debug("") }
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
            .responseData { [weak self] in
                self?.handleSpeakersResponse($0, completion: completion)
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
    func handleSpeakersResponse(_ response: AFDataResponse<Data>, completion: @escaping SpeakersRequestCompletion) {
        switch response.result {
        case .success(let data):
            guard let decoded = try? JSONDecoder().decode([VoicevoxSpeakerResponse].self, from: data) else {
                completion(Result.failure(.internal))
                return
            }
            completion(Result.success(decoded.toVoicevoxSpeakers()))
        case .failure(let error):
            log.error(error)
            completion(Result.failure(error.asVoicevoxWrapperError))
        }
    }

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
            // log.debug(String(bytes: _data, encoding: .utf8) ?? "")
            requestSynthesis(data: _data, config: config, completion: completion)
        case .failure(let error):
            log.error("[\(config.text)] \(error)")
            completion(Result.failure(error.asVoicevoxWrapperError))
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
            completion(Result.failure(error.asVoicevoxWrapperError))
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

private extension Error {
    // Sample [Could not connect to the server.]:
    // -----
    // sessionTaskFailed(error: Error Domain=NSURLErrorDomain Code=-1004 "Could
    // not connect to the server." UserInfo={_kCFStreamErrorCodeKey=61,
    // NSUnderlyingError=0x60000038f810 {Error Domain=kCFErrorDomainCFNetwork ...

    // Sample [The network connection was lost.]:
    // -----
    // sessionTaskFailed(error: Error Domain=NSURLErrorDomain Code=-1005 "The
    // network connection was lost." UserInfo={_kCFStreamErrorCodeKey=-4,
    // NSUnderlyingError=0x600002c9ec40 {Error Domain=kCFErrorDomainCFNetwork ...
    var asVoicevoxWrapperError: VoicevoxWrapperError {
        guard let code = asSessionTaskFailedErrorCode else { return .internal }
        switch code {
        case -1004: return .couldNotConnect
        case -1005: return .lostConnection
        default:    return .internal
        }
    }

    var asSessionTaskFailedErrorCode: Int? {
        guard let afError = self as? AFError else { return nil }
        switch afError {
        case .sessionTaskFailed(error: let error):
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                return nsError.code
            }
        default:
            break
        }
        return nil
    }
}
