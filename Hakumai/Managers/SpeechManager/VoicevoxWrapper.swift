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
    func requestAudio(text: String, speedScale: Float, completion: @escaping (Result<Data, VoicevoxWrapperError>) -> Void)
}

enum VoicevoxWrapperError: Error {
    case `internal`
}

private let voicevoxUrl = "http://localhost:50021"

final class VoicevoxWrapper: VoicevoxWrapperType {}

extension VoicevoxWrapper {
    func requestAudio(text: String, speedScale: Float, completion: @escaping (Result<Data, VoicevoxWrapperError>) -> Void) {
        requestAudioQuery(text: text, speedScale: speedScale, completion: completion)
    }
}

private extension VoicevoxWrapper {
    func requestAudioQuery(text: String, speedScale: Float, completion: @escaping (Result<Data, VoicevoxWrapperError>) -> Void) {
        let urlString = voicevoxUrl + "/audio_query?text=\(text.escapsed)&speaker=2"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .post
        AF.request(request)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseString { [weak self] in
                guard let me = self else { return }
                log.debug(text)
                log.debug(speedScale)
                switch $0.result {
                case .success(let json):
                    log.debug(json)
                    //     ("^(/vote )(.+)$", "$1アンケ $2"),
                    let speedAdjusted = json.stringByReplacingRegexp(
                        pattern: "(\"speedScale\":)1.0(,)", with: "$1\(speedScale)$2")
                    log.debug(speedAdjusted)
                    me.requestSynthesis(json: speedAdjusted, completion: completion)
                case .failure(let error):
                    log.error(error)
                    completion(Result.failure(VoicevoxWrapperError.internal))
                }
            }
    }

    func requestSynthesis(json: String, completion: @escaping (Result<Data, VoicevoxWrapperError>) -> Void) {
        let urlString = voicevoxUrl + "/synthesis?speaker=2"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .post
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = json.data(using: .utf8)
        AF.request(request)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData {
                // guard let me = self else { return }
                switch $0.result {
                case .success(let data):
                    log.debug(data)
                    completion(Result.success(data))
                case .failure(let error):
                    log.error(error)
                    completion(Result.failure(VoicevoxWrapperError.internal))
                }
            }
    }
}

private extension String {
    var escapsed: String { URLEncoding.default.escape(self) }
}
