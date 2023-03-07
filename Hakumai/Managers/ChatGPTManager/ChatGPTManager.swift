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
private let httpHeaderKeyContentType = "Content-Type"
private let httpHeaderKeyAuthorization = "Authorization"
private let httpHeaderValueApplicationJson = "application/json"

final class ChatGPTManager {
    static let shared = ChatGPTManager()
}

extension ChatGPTManager: ChatGPTManagerType {
    func generateComment(type: ChatGPTManagerCommentType, sampleComments: [String], completion: @escaping ([String]) -> Void) {
        let urlString = "https://" + apiHost + apiPath
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.method = .post
        request.setValue(httpHeaderValueApplicationJson, forHTTPHeaderField: httpHeaderKeyContentType)
        request.setValue("Bearer \(openAIAPIToken)", forHTTPHeaderField: httpHeaderKeyAuthorization)
        let payload = makeRequestPayload(message: "", samples: sampleComments)
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
    func makeRequestPayload(message: String, samples: [String]) -> ChatCompletionRequest {
        return ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [
                ChatCompletionRequestMessage(
                    role: "system",
                    content: "あなたはインターネット生放送にコメントするリスナーです。言葉遣いはですます調ではなく、友達同士で話しているようなラフな感じです。"
                ),
                ChatCompletionRequestMessage(
                    role: "user",
                    content: "いま生放送には次のようなコメントが流れています。これらを参考にして、自分もリスナーになった気分でコメントを考えてください。コメントは日本語で100文字以内、5つ、数字付きの箇条書きで答えてください。\n\n" +
                        samples.map({"* \($0)"}).joined(separator: "\n")
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
