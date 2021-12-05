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
private let queryInterval: TimeInterval = 15

final class LiveThumbnailFetcher {
    private var liveProgramId: String?
    private var liveThumbnailUrl: URL?
    private weak var delegate: LiveThumbnailFetcherDelegate?
    private var timer: Timer?
}

extension LiveThumbnailFetcher: LiveThumbnailFetcherProtocol {
    func start(for liveProgramId: String, delegate: LiveThumbnailFetcherDelegate) {
        self.liveProgramId = liveProgramId
        self.delegate = delegate
        scheduleTimer()
    }

    func stop() {
        invalidateTimer()
    }
}

private extension LiveThumbnailFetcher {
    func scheduleTimer() {
        timer = Timer.scheduledTimer(
            timeInterval: queryInterval,
            target: self,
            selector: #selector(LiveThumbnailFetcher.makeLiveThumbnailUrl),
            userInfo: nil,
            repeats: true)
        log.debug("Scheduled timer.")
        timer?.fire()
    }

    func invalidateTimer() {
        timer?.invalidate()
        timer = nil
        log.debug("Invalidated timer.")
    }

    @objc
    func makeLiveThumbnailUrl() {
        guard let liveProgramId = liveProgramId else {
            log.error("Missing live program id: \(self.liveProgramId ?? "-")")
            return
        }
        if let liveThumbnailUrl = liveThumbnailUrl,
           let url = constructLiveThumbnailUrl(from: liveThumbnailUrl, for: Date()) {
            log.debug("Made live thumbnail url: \(url.absoluteString)")
            delegate?.liveThumbnailFetcher(
                self, didGetThumbnailUrl: url, forLiveProgramId: liveProgramId)
            return
        }
        queryLivePage(liveProgramId: liveProgramId)
    }

    func queryLivePage(liveProgramId: String) {
        guard let livePageUrl = URL(string: livePageBaseUrl + liveProgramId) else {
            log.error("Invalid live page url: \(self.liveProgramId ?? "-")")
            return
        }
        var request = URLRequest(url: livePageUrl)
        request.headers = [commonUserAgentKey: commonUserAgentValue]
        AF.request(request)
            // .cURLDescription { log.debug($0) }
            .validate()
            .responseString { [weak self] in
                guard let me = self else { return }
                switch $0.result {
                case .success(let html):
                    guard let url = me.extractLiveThumbnailUrl(from: html) else {
                        log.error("Live thumbnail extraction failed.")
                        return
                    }
                    me.liveThumbnailUrl = url
                    log.debug("Fetched live thumbnail url: \(url.absoluteString)")
                    me.delegate?.liveThumbnailFetcher(
                        me, didGetThumbnailUrl: url, forLiveProgramId: liveProgramId)
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

    func constructLiveThumbnailUrl(from thumbnailUrl: URL, for date: Date) -> URL? {
        let baseUrl = thumbnailUrl.absoluteString.stringByRemovingRegexp(pattern: "\\?t=\\d+$")
        let time = Int(date.timeIntervalSince1970 * 1000)
        return URL(string: baseUrl + "?t=\(time)")
    }
}

// Extension for unit testing.
// https://stackoverflow.com/a/50136916/13220031
#if DEBUG
extension LiveThumbnailFetcher {
    func exposedExtractLiveThumbnailUrl(from html: String) -> URL? {
        return extractLiveThumbnailUrl(from: html)
    }

    func exposedConstructLiveThumbnailUrl(from thumbnailUrl: URL, for date: Date) -> URL? {
        return constructLiveThumbnailUrl(from: thumbnailUrl, for: date)
    }
}
#endif
