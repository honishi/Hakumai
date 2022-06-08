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
    private(set) var browser: BrowserInUseType = .chrome
    private(set) weak var delegate: BrowserUrlObserverDelegate?
    private var timer: Timer?
}

extension BrowserUrlObserver: BrowserUrlObserverType {
    func setBrowserType(_ browser: BrowserInUseType) {
        self.browser = browser
        log.debug("set browser: \(browser)")
    }

    func start(delegate: BrowserUrlObserverDelegate) {
        self.delegate = delegate
        scheduleTimer()
    }

    func stop() {
        invalidateTimer()
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
        guard let urlString = BrowserHelper.extractUrl(fromBrowser: browser.toBrowserHelperBrowserType),
              urlString.isLiveUrl,
              let url = URL(string: urlString) else { return }
        delegate?.browserUrlObserver(self, didGetUrl: url)
    }
}
