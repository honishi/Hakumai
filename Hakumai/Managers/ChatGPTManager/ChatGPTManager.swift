//
//  ChatGPTManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2023/03/07.
//  Copyright © 2023 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

private let apiHost = "api.openai.com"
private let apiPath = "/v1/chat/completions"
private let whisperApiPath = "/v1/audio/transcriptions"
private let httpHeaderKeyContentType = "Content-Type"
private let httpHeaderKeyAuthorization = "Authorization"
private let httpHeaderValueApplicationJson = "application/json"

final class ChatGPTManager {
    static let shared = ChatGPTManager()
}

extension ChatGPTManager: ChatGPTManagerType {
    func transcribeAudio(_ data: Data, completion: @escaping (String?) -> Void) {
        let urlString = "https://" + apiHost + whisperApiPath
        guard let url = URL(string: urlString) else { return }
        AF.upload(
            multipartFormData: {
                guard let model = "whisper-1".data(using: .utf8),
                      let text = "text".data(using: .utf8) else { return }
                $0.append(model, withName: "model")
                // $0.append(data, withName: "file", fileName: "audio.m4a", mimeType: "audio/wav")
                $0.append(data, withName: "file", fileName: "audio.mp4", mimeType: "video/mp4")
                $0.append(text, withName: "response_format")
            },
            to: url,
            headers: [
                httpHeaderKeyAuthorization: "Bearer \(openAIAPIToken)"
            ])
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseString {
                log.debug($0)
                switch $0.result {
                case .success(let str):
                    let text = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    log.debug(text)
                    completion(text)
                case .failure(let error):
                    log.error(error)
                    log.error(error.errorDescription)
                    log.error($0.data)
                    guard let data = $0.data else { return }
                    log.error(String(data: data, encoding: .utf8))
                }
            }
    }

    func generateComment(spokeText: String, comments: [String], completion: @escaping ([String]) -> Void) {
        let urlString = "https://" + apiHost + apiPath
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .post
        request.setValue(httpHeaderValueApplicationJson, forHTTPHeaderField: httpHeaderKeyContentType)
        request.setValue("Bearer \(openAIAPIToken)", forHTTPHeaderField: httpHeaderKeyAuthorization)
        let payload = makeRequestPayload(spokeText: spokeText, comments: comments)
        guard let encoded = try? JSONEncoder().encode(payload) else {
            fatalError()
        }
        request.httpBody = encoded
        AF.request(request)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData { [weak self] in
                log.debug($0)
                switch $0.result {
                case .success(let data):
                    self?.handleResponse(data: data, completion: completion)
                case .failure:
                    completion([])
                }
            }
    }
}

private extension ChatGPTManager {
    func makeRequestPayload(spokeText: String, comments: [String]) -> ChatCompletionRequest {
        return ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [
                ChatCompletionRequestMessage(
                    role: "system",
                    content: """
                    あなたは、インターネット生放送の視聴者です。
                    あなたはコメントを通じて、生放送主と会話をしています。
                    会話はお互いに煽り合う形で進んでいます。
                    """
                ),
                ChatCompletionRequestMessage(
                    role: "user",
                    content: """
                    # 命令書:
                    あなたは、インターネット生放送の視聴者です。
                    以下の制約条件と入力文をもとに、コメントを考えてください。

                    # 制約条件:
                    コメントは10個。
                    煽り調のコメントを考える。
                    コメント種別の括弧書きは不要。
                    1行1コメント。
                    文字数は1コメントあたり日本語で30文字以内。
                    数字付きの箇条書き。
                    鉤括弧は不要でコメント本文のみを列挙。

                    #入力文:
                    \(spokeText)

                    #出力文:
                    """
                )
            ]
        )
    }

    func handleResponse(data: Data, completion: @escaping ([String]) -> Void) {
        guard let response = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
              let content = response.choices.first?.message.content else {
            return
        }
        log.debug(content)
        let comments = content
            .split(separator: "\n")
            .map({ String($0) })
            .map({ $0.extractRegexp(pattern: ".+\\s(.+)") })
            .compactMap({ $0 })
        completion(comments)
    }
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatCompletionRequestMessage]
}

struct ChatCompletionRequestMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let choices: [ChatCompletionResponseChoice]
}

struct ChatCompletionResponseChoice: Codable {
    let message: ChatCompletionResponseMessage
}

struct ChatCompletionResponseMessage: Codable {
    let role: String
    let content: String
}
