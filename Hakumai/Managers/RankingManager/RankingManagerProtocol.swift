//
//  RankingManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/10/30.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol RankingManagerType {
    func queryRank(liveNumber: String, completion: @escaping (Int?) -> Void)
}
