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
private let maxPage = 5

final class RankingManager {
    private var isRequesting = false
}

extension RankingManager: RankingManagerType {
    func queryRank(liveId: String, completion: @escaping (Int?) -> Void) {
        log.info("Starting rank query for (\(liveId)")
        guard !isRequesting else {
            log.error("Previous request is still in progress, reject the query request.")
            completion(nil)
            return
        }
        queryRank(liveId: liveId, page: 1, completion: completion)
    }
}

private extension RankingManager {
    func queryRank(liveId: String, page: Int, completion: @escaping (Int?) -> Void) {
        log.debug("Processing page \(page) for (\(liveId)")
        guard let urlString = rankingUrlString(for: page),
              let url = URL(string: urlString)
        else {
            log.debug("Query page reached to max, quit to further requesting.")
            completion(nil)
            isRequesting = false
            return
        }
        isRequesting = true
        log.debug("Start page request...")
        var request = URLRequest(url: url)
        request.headers = [commonUserAgentKey: commonUserAgentValue]
        AF.request(request)
            .cURLDescription { log.debug($0) }
            .validate()
            .responseString { [weak self] in
                switch $0.result {
                case .success(let html):
                    if let rank = self?.extractRank(from: html, liveId: liveId) {
                        log.debug("Rank found -> \(rank), query finished.")
                        completion(rank)
                        self?.isRequesting = false
                    } else {
                        // Continue to request further page recursively.
                        let nextPage = page + 1
                        log.debug("Rank not found, go further page -> \(nextPage)")
                        self?.queryRank(
                            liveId: liveId,
                            page: nextPage,
                            completion: completion)
                    }
                case .failure(let error):
                    log.error("Error.")
                    log.error(error)
                    completion(nil)
                    self?.isRequesting = false
                }
            }
    }

    func rankingUrlString(for page: Int) -> String? {
        if page == 1 {
            return chikuranUrl
        } else if page <= maxPage {
            return chikuranUrl + "index.cgi?page=\(page)"
        }
        return nil
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
