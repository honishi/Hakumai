//
//  ChatGPTManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2023/03/07.
//  Copyright © 2023 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol ChatGPTManagerType {
    func generateComment(type: ChatGPTManagerCommentType, sampleComments: [String], completion: (String) -> Void)
}

enum ChatGPTManagerCommentType {
    case greeting
}
