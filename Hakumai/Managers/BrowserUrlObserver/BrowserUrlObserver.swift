//
//  BrowserUrlObserver.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/07.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let timerInterval: TimeInterval = 3

final class BrowserUrlObserver {
    struct IgnoreLive {
        let untilDate: Date
        let liveProgramId: String
    }

    private(set) var browser: BrowserInUseType = .chrome
    private(set) weak var delegate: BrowserUrlObserverDelegate?
    private var timer: Timer?
    private var ignoreLives: [IgnoreLive] = []
}

extension BrowserUrlObserver: BrowserUrlObserverType {
    func setBrowserType(_ browser: BrowserInUseType) {
        self.browser = browser
        log.debug("set browser: \(browser)")
    }

    func start(delegate: BrowserUrlObserverDelegate) {
        self.delegate = delegate
        ignoreLives.removeAll()
        scheduleTimer()
    }

    func stop() {
        invalidateTimer()
    }

    func ignoreLive(liveProgramId: String, seconds: TimeInterval) {
        ignoreLives.append(
            IgnoreLive(
                untilDate: Date().addingTimeInterval(seconds),
                liveProgramId: liveProgramId
            )
        )
    }
}

private extension BrowserUrlObserver {
    func scheduleTimer() {
        timer = Timer.scheduledTimer(
            timeInterval: timerInterval,
            target: self,
            selector: #selector(BrowserUrlObserver.timerFired),
            userInfo: nil,
            repeats: true)
        log.debug("Scheduled timer.")
    }

    func invalidateTimer() {
        timer?.invalidate()
        timer = nil
        log.debug("Invalidated timer.")
    }

    @objc
    func timerFired() {
        refreshIgnoreLives()
        guard let urlString = BrowserHelper.extractUrl(fromBrowser: browser.toBrowserHelperBrowserType),
              let liveProgramId = urlString.extractLiveProgramId(),
              !ignoreLives.map({ $0.liveProgramId }).contains(liveProgramId),
              let url = URL(string: urlString) else { return }
        delegate?.browserUrlObserver(self, didGetUrl: url)
    }

    func refreshIgnoreLives() {
        let origin = Date()
        ignoreLives = ignoreLives
            .filter { $0.untilDate.timeIntervalSince(origin) > 0 }
        // log.debug(ignoreLives)
    }
}
