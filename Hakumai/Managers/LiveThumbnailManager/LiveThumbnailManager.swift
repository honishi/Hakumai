//
//  LiveThumbnailManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire
import Kanna

private let livePageBaseUrl = "https://live.nicovideo.jp/watch/"
private let timerInterval: TimeInterval = 60

final class LiveThumbnailManager {
    private var liveProgramId: String?
    private var originalThumbnailUrl: URL?
    private weak var delegate: LiveThumbnailManagerDelegate?
    private var timer: Timer?
}

extension LiveThumbnailManager: LiveThumbnailManagerType {
    func start(for liveProgramId: String, delegate: LiveThumbnailManagerDelegate) {
        self.liveProgramId = liveProgramId
        self.delegate = delegate
        self.originalThumbnailUrl = nil
        scheduleTimer()
    }

    func stop() {
        invalidateTimer()
    }
}

private extension LiveThumbnailManager {
    func scheduleTimer() {
        timer = Timer.scheduledTimer(
            timeInterval: timerInterval,
            target: self,
            selector: #selector(LiveThumbnailManager.timerFired),
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
    func timerFired() {
        guard let liveProgramId = liveProgramId else {
            log.error("Missing live program id: \(self.liveProgramId ?? "-")")
            return
        }
        if let originalThumbnailUrl = originalThumbnailUrl {
            makeThumbnailUrl(from: originalThumbnailUrl, for: liveProgramId)
            return
        }
        queryLivePage(liveProgramId: liveProgramId)
    }

    func makeThumbnailUrl(from originalUrl: URL, for liveProgramId: String) {
        guard let url = constructThumbnailUrl(from: originalUrl, for: Date()) else {
            log.debug("Skipped to make live thumbnail url for \(liveProgramId).")
            return
        }
        log.debug("Made live thumbnail url: \(url.absoluteString)")
        delegate?.liveThumbnailManager(
            self, didGetThumbnailUrl: url, forLiveProgramId: liveProgramId)
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
                    guard let url = me.extractThumbnailUrl(from: html) else {
                        log.error("Live thumbnail extraction failed.")
                        return
                    }
                    me.originalThumbnailUrl = url
                    log.debug("Fetched live thumbnail url: \(url.absoluteString)")
                    me.delegate?.liveThumbnailManager(
                        me, didGetThumbnailUrl: url, forLiveProgramId: liveProgramId)
                case .failure(let error):
                    // No-op.
                    log.error(error)
                }
            }
    }

    func extractThumbnailUrl(from html: String) -> URL? {
        guard let doc = try? HTML(html: html, encoding: .utf8),
              let ogImage = doc.xpath("//meta[@property=\"og:image\"]").first,
              let content = ogImage["content"] else { return nil }
        return URL(string: content)
    }

    func constructThumbnailUrl(from thumbnailUrl: URL, for date: Date) -> URL? {
        // 2023/11 update:
        // Seems this construction is no longer needed. So just use original url.
        return thumbnailUrl
        /*
         let timePattern = "\\?t=\\d+$"
         let urlString = thumbnailUrl.absoluteString
         guard urlString.hasRegexp(pattern: timePattern) else { return nil }
         let baseUrl = urlString.stringByRemovingRegexp(pattern: timePattern)
         let time = Int(date.timeIntervalSince1970 * 1000)
         return URL(string: baseUrl + "?t=\(time)")
         */
    }
}

// Extension for unit testing.
// https://stackoverflow.com/a/50136916/13220031
#if DEBUG
extension LiveThumbnailManager {
    func exposedExtractThumbnailUrl(from html: String) -> URL? {
        return extractThumbnailUrl(from: html)
    }

    func exposedConstructThumbnailUrl(from thumbnailUrl: URL, for untilDate: Date) -> URL? {
        return constructThumbnailUrl(from: thumbnailUrl, for: untilDate)
    }
}
#endif
