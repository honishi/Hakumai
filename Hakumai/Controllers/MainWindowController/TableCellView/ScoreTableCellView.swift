//
//  ScoreTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class ScoreTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var scoreLabel: NSTextField!

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }
}

extension ScoreTableCellView {
    func configure(live: Live?, chat: Chat?) {
        coloredView.fillColor = color(forChatScore: chat)
        scoreLabel.stringValue = time(live: live, chat: chat)
    }
}

private extension ScoreTableCellView {
    func color(forChatScore chat: Chat?) -> NSColor {
        // println("\(score)")
        guard let chat = chat else { return UIHelper.systemMessageColorBackground() }
        return chat.isSystemComment ? UIHelper.systemMessageColorBackground() : UIHelper.scoreColorGreen()
    }

    func time(live: Live?, chat: Chat?) -> String {
        guard let beginDate = live?.startTime, let chatDate = chat?.date else { return "-" }
        let comps = Calendar.current.dateComponents(
            [.hour, .minute, .second], from: beginDate, to: chatDate)
        guard let h = comps.hour, let m = comps.minute, let s = comps.second else { return "-" }
        return "\(h):\(m.zeroPadded):\(s.zeroPadded)"
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        scoreLabel.font = NSFont.systemFont(ofSize: size)
    }
}

private extension Int {
    var zeroPadded: String { String(format: "%02d", self) }
}
