//
//  TimeTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let defaultTimeValue = "-"

final class TimeTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var timeLabel: NSTextField!

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }
}

extension TimeTableCellView {
    func configure(live: Live?, message: Message?) {
        coloredView.fillColor = color(message: message)
        timeLabel.stringValue = time(live: live, message: message)
    }
}

private extension TimeTableCellView {
    func color(message: Message?) -> NSColor {
        guard let message = message else { return UIHelper.systemMessageColorBackground() }
        switch message.content {
        case .system:
            return UIHelper.systemMessageColorBackground()
        case .chat(let chat):
            return chat.isSystem ? UIHelper.systemMessageColorBackground() : UIHelper.scoreColorGreen()
        case .debug:
            return UIHelper.debugMessageColorBackground()
        }
    }

    func time(live: Live?, message: Message?) -> String {
        guard let message = message else { return defaultTimeValue }
        switch message.content {
        case .system, .debug:
            return "[\(message.date.toLocalTimeString())]"
        case .chat(chat: let chat):
            guard let beginDate = live?.beginTime,
                  let elapsed = chat.date.toElapsedTimeString(from: beginDate) else {
                return defaultTimeValue
            }
            return elapsed
        }
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        timeLabel.font = NSFont.systemFont(ofSize: size)
    }
}

private extension Date {
    func toElapsedTimeString(from fromDate: Date) -> String? {
        let comps = Calendar.current.dateComponents(
            [.hour, .minute, .second], from: fromDate, to: self)
        guard let h = comps.hour, let m = comps.minute, let s = comps.second else { return nil }
        return "\(h):\(m.zeroPadded):\(s.zeroPadded)"
    }

    func toLocalTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm:ss"
        return formatter.string(from: self)
    }
}

private extension Int {
    var zeroPadded: String { String(format: "%02d", self) }
}
