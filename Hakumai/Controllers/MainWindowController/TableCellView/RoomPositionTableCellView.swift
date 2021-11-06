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

    var roomPosition: RoomPosition? {
        didSet {
            coloredView.fillColor = color(forRoomPosition: roomPosition)
        }
    }
    var commentNo: Int? { didSet { commentNoLabel.stringValue = string(ofCommentNo: commentNo) } }
    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }
}

private extension RoomPositionTableCellView {
    func color(forRoomPosition roomPosition: RoomPosition?) -> NSColor {
        return roomPosition == nil ? UIHelper.systemMessageColorBackground() : UIHelper.roomColorArena()
    }

    func string(ofCommentNo commentNo: Int?) -> String {
        guard let commentNo = commentNo else { return "" }
        return String(commentNo).numberStringWithSeparatorComma()
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        commentNoLabel.font = NSFont.systemFont(ofSize: size)
    }
}
