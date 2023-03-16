//
//  OpenAIManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2023/03/07.
//  Copyright © 2023 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol OpenAIManagerType {
    func transcribeAudio(_ data: Data, completion: @escaping (String?) -> Void)
    func generateComment(spokeText: String, comments: [String], completion: @escaping ([String]?) -> Void)
}
