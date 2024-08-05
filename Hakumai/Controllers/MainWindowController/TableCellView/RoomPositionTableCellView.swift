//
//  RoomPositionTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class RoomPositionTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var commentNoLabel: NSTextField!

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }
}

extension RoomPositionTableCellView {
    func configure(message: Message?) {
        coloredView.fillColor = color(for: message)
        commentNoLabel.stringValue = string(for: message)
    }
}

private extension RoomPositionTableCellView {
    func color(for message: Message?) -> NSColor {
        guard let message = message else { return UIHelper.systemMessageBgColor() }
        switch message.content {
        case .system:
            return UIHelper.systemMessageBgColor()
        case .chat(let chat):
            return UIHelper.roomColor(roomPosition: chat.roomPosition)
        case .debug:
            return UIHelper.debugMessageBgColor()
        }
    }

    func string(for message: Message?) -> String {
        guard case let .chat(chat) = message?.content else { return "" }
        if chat.no == 0 {
            return "---"
        }
        return String(chat.no).numberStringWithSeparatorComma()
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        commentNoLabel.font = NSFont.systemFont(ofSize: size)
    }
}
