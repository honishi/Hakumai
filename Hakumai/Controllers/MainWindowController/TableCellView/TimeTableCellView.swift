//
//  TimeTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class TimeTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var timeLabel: NSTextField!

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }
}

extension TimeTableCellView {
    func configure(live: Live?, chat: Chat?) {
        coloredView.fillColor = color(chat: chat)
        timeLabel.stringValue = time(live: live, chat: chat)
    }
}

private extension TimeTableCellView {
    func color(chat: Chat?) -> NSColor {
        guard let chat = chat else { return UIHelper.systemMessageColorBackground() }
        return chat.isSystemComment ? UIHelper.systemMessageColorBackground() : UIHelper.scoreColorGreen()
    }

    func time(live: Live?, chat: Chat?) -> String {
        guard let beginDate = live?.beginTime, let chatDate = chat?.date else { return "-" }
        return chatDate.toElapsedTimeString(from: beginDate)
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        timeLabel.font = NSFont.systemFont(ofSize: size)
    }
}

private extension Date {
    func toElapsedTimeString(from fromDate: Date) -> String {
        let comps = Calendar.current.dateComponents(
            [.hour, .minute, .second], from: fromDate, to: self)
        guard let h = comps.hour, let m = comps.minute, let s = comps.second else { return "-" }
        return "\(h):\(m.zeroPadded):\(s.zeroPadded)"
    }
}

private extension Int {
    var zeroPadded: String { String(format: "%02d", self) }
}
