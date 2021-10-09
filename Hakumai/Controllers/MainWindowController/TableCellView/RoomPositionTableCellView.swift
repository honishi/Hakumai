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
    @IBOutlet weak var roomPositionLabel: NSTextField!
    @IBOutlet weak var commentNoLabel: NSTextField!

    var roomPosition: RoomPosition? {
        didSet {
            roomPositionLabel.stringValue = string(forRoomPosition: roomPosition)
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

    func string(forRoomPosition roomPosition: RoomPosition?) -> String {
        guard let roomPosition = roomPosition else { return "" }
        return roomPosition.shortLabel() + ":"
    }

    func string(ofCommentNo commentNo: Int?) -> String {
        guard let commentNo = commentNo else { return "" }
        return String(commentNo).numberStringWithSeparatorComma()
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        roomPositionLabel.font = NSFont.systemFont(ofSize: size)
        commentNoLabel.font = NSFont.systemFont(ofSize: size)
    }
}
