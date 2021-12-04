//
//  LiveThumbnailFetcher.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire
import Kanna

private let livePageBaseUrl = "https://live.nicovideo.jp/watch/"
private let queryInterval: TimeInterval = 30

final class LiveThumbnailFetcher {
    private var liveProgramId: String?
    private weak var delegate: LiveThumbnailFetcherDelegate?
    private var queryTimer: Timer?
}

extension LiveThumbnailFetcher: LiveThumbnailFetcherProtocol {
    func start(for liveProgramId: String, delegate: LiveThumbnailFetcherDelegate) {
        self.liveProgramId = liveProgramId
        self.delegate = delegate
        scheduleQueryTimer()
    }

    func stop() {
        invalidateQueryTimer()
    }
}

private extension LiveThumbnailFetcher {
    func scheduleQueryTimer() {
        queryTimer = Timer.scheduledTimer(
            timeInterval: queryInterval,
            target: self,
            selector: #selector(LiveThumbnailFetcher.queryLivePage),
            userInfo: nil,
            repeats: true)
        log.debug("Scheduled query timer.")
        queryTimer?.fire()
    }

    func invalidateQueryTimer() {
        queryTimer?.invalidate()
        queryTimer = nil
        log.debug("Invalidated query timer.")
    }

    @objc
    func queryLivePage() {
        guard let liveProgramId = liveProgramId,
              let url = URL(string: livePageBaseUrl + liveProgramId) else {
            log.error("Invalid live page url: \(self.liveProgramId ?? "-")")
            return
        }
        var request = URLRequest(url: url)
        request.headers = [commonUserAgentKey: commonUserAgentValue]
        AF.request(request)
            // .cURLDescription { log.debug($0) }
            .validate()
            .responseString { [weak self] in
                guard let me = self else { return }
                switch $0.result {
                case .success(let html):
                    guard let thumbnailUrl = me.extractLiveThumbnailUrl(from: html) else {
                        log.error("Live thumbnail extraction failed.")
                        return
                    }
                    me.delegate?.liveThumbnailFetcher(
                        me, didGetThumbnailUrl: thumbnailUrl, forLiveProgramId: liveProgramId)
                case .failure(let error):
                    // No-op.
                    log.error(error)
                }
            }
    }

    func extractLiveThumbnailUrl(from html: String) -> URL? {
        guard let doc = try? HTML(html: html, encoding: .utf8),
              let ogImage = doc.xpath("//meta[@property=\"og:image\"]").first,
              let content = ogImage["content"] else { return nil }
        return URL(string: content)
    }
}

// Extension for unit testing.
// https://stackoverflow.com/a/50136916/13220031
#if DEBUG
extension LiveThumbnailFetcher {
    func exposedExtractLiveThumbnailUrl(from html: String) -> URL? {
        return extractLiveThumbnailUrl(from: html)
    }
}
#endif
