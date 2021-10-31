//
//  RankingManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/10/30.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol RankingManagerType {
    func addDelegate(delegate: RankingManagerDelegate, for liveId: String)
    func removeDelegate(delegate: RankingManagerDelegate)
    var isRunning: Bool { get }
}

protocol RankingManagerDelegate: AnyObject {
    func rankingManager(_ rankingManager: RankingManagerType, didUpdateRank rank: Int?, for liveId: String)
    func rankingManager(_ rankingManager: RankingManagerType, hasDebugMessage message: String)
}

extension RankingManagerDelegate {
    func rankingManager(_ rankingManager: RankingManagerType, hasDebugMessage message: String) {}
}
