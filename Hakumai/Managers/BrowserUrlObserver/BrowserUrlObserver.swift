//
//  BrowserUrlObserver.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/07.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let timerInterval: TimeInterval = 5

final class BrowserUrlObserver {
    private(set) var browser: BrowserInUseType = .chrome
    private(set) weak var delegate: BrowserUrlObserverDelegate?
    private var timer: Timer?
    private var liveProgramIds: Set<String> = []
}

extension BrowserUrlObserver: BrowserUrlObserverType {
    func setBrowserType(_ browser: BrowserInUseType) {
        self.browser = browser
        log.debug("set browser: \(browser)")
    }

    func start(delegate: BrowserUrlObserverDelegate) {
        self.delegate = delegate
        liveProgramIds.removeAll()
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
              let liveProgramId = urlString.extractLiveProgramId(),
              !liveProgramIds.contains(liveProgramId),
              let url = URL(string: urlString) else { return }
        liveProgramIds.insert(liveProgramId)
        delegate?.browserUrlObserver(self, didGetUrl: url)
    }
}
