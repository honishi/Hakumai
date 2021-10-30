//
//  RankingManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/10/30.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

private let chikuranUrl = "http://www.chikuwachan.com/live/"
private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36"

final class RankingManager {
    //
}

extension RankingManager: RankingManagerType {
    func queryRank(liveNumber: String, completion: @escaping (Int?) -> Void) {
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
                    log.debug(html)
                    completion(123)
                case .failure(let error):
                    log.error(error)
                    completion(nil)
                }
            }
    }
}
