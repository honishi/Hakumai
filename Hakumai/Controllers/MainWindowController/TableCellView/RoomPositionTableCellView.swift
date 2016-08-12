//
//  RoomPositionTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class RoomPositionTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var roomPositionLabel: NSTextField!
    @IBOutlet weak var commentNoLabel: NSTextField!
    
    var roomPosition: RoomPosition? {
        didSet {
            roomPositionLabel.stringValue = stringForRoomPosition(roomPosition)
            coloredView.fillColor = colorForRoomPosition(roomPosition)
        }
    }
    
    var commentNo: Int? {
        didSet {
            commentNoLabel.stringValue = commentNoString(commentNo)
        }
    }
    
    var fontSize: CGFloat? {
        didSet {
            setFontSize(fontSize)
        }
    }
    
    // MARK: - Internal Functions
    private func colorForRoomPosition(_ roomPosition: RoomPosition?) -> NSColor {
        if roomPosition == nil {
            return UIHelper.systemMessageColorBackground()
        }
        
        switch (roomPosition!) {
        case .arena:
            return UIHelper.roomColorArena()
        case .standA:
            return UIHelper.roomColorStandA()
        case .standB:
            return UIHelper.roomColorStandB()
        case .standC:
            return UIHelper.roomColorStandC()
        case .standD:
            return UIHelper.roomColorStandD()
        case .standE:
            return UIHelper.roomColorStandE()
        case .standF:
            return UIHelper.roomColorStandF()
        case .standG:
            return UIHelper.roomColorStandG()
        case .standH:
            return UIHelper.roomColorStandH()
        case .standI:
            return UIHelper.roomColorStandI()
        case .standJ:
            return UIHelper.roomColorStandJ()
        }
    }
    
    private func stringForRoomPosition(_ roomPosition: RoomPosition?) -> String {
        guard let roomPosition = roomPosition else {
            return ""
        }

        return roomPosition.shortLabel() + ":"
    }
    
    private func commentNoString(_ commentNo: Int?) -> String {
        guard let commentNo = commentNo else {
            return ""
        }

        return String(commentNo).numberStringWithSeparatorComma()!
    }
    
    private func setFontSize(_ fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        roomPositionLabel.font = NSFont.systemFont(ofSize: size)
        commentNoLabel.font = NSFont.systemFont(ofSize: size)
    }
}
