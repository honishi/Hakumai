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
    func configure(live: Live?, message: Message?) {
        coloredView.fillColor = color(message: message)
        timeLabel.stringValue = time(live: live, chat: message?.chat)
    }
}

private extension TimeTableCellView {
    func color(message: Message?) -> NSColor {
        guard let message = message else { return UIHelper.systemMessageColorBackground() }
        switch message.messageType {
        case .system:
            return UIHelper.systemMessageColorBackground()
        case .chat:
            guard let chat = message.chat else { return UIHelper.systemMessageColorBackground() }
            return chat.isSystemComment ? UIHelper.systemMessageColorBackground() : UIHelper.scoreColorGreen()
        case .debug:
            return UIHelper.debugMessageColorBackground()
        }
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
