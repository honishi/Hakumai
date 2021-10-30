//
//  RankingManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/10/30.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire
import Kanna

private let chikuranUrl = "http://www.chikuwachan.com/live/"

final class RankingManager {}

extension RankingManager: RankingManagerType {
    func queryRank(liveId: String, completion: @escaping (Int?) -> Void) {
        guard let url = URL(string: chikuranUrl) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.headers = [commonUserAgentKey: commonUserAgentValue]
        AF.request(request)
            .cURLDescription { log.debug($0) }
            .validate()
            .responseString {
                switch $0.result {
                case .success(let html):
                    let rank = self.extractRank(from: html, liveId: liveId)
                    completion(rank)
                case .failure(let error):
                    log.error(error)
                    completion(nil)
                }
            }
    }

    func extractRank(from html: String, liveId: String) -> Int? {
        guard let doc = try? HTML(html: html, encoding: .utf8) else { return nil }
        for live in doc.xpath("//div[contains(@class, \"live\")]") {
            guard let rankText = live.xpath("//div[@class=\"rank\"]").first?.text,
                  let rank = Int(rankText),
                  let linkText = live.xpath("//div[@class=\"title\"]/a").first?["href"],
                  let _liveId = linkText.extractLiveProgramId() else { continue }
            if liveId == _liveId {
                return rank
            }
        }
        return nil
    }
}
