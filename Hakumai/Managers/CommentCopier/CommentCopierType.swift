//
//  CommentCopierType.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/18.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol CommentCopierType {
    static func make(live: Live, messageContainer: MessageContainer, nicoManager: NicoManagerType, handleNameManager: HandleNameManager) -> CommentCopierType
    func copy(completion: (() -> Void)?)
}
