//
//  ChatGPTManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2023/03/07.
//  Copyright © 2023 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class ChatGPTManager {
    static let shared = ChatGPTManager()
}

extension ChatGPTManager: ChatGPTManagerType {
    func generateComment(type: ChatGPTManagerCommentType, sampleComments: [String], completion: (String) -> Void) {
        completion("hello")
    }
}
