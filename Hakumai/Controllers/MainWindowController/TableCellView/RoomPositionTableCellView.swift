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
    private func colorForRoomPosition(roomPosition: RoomPosition?) -> NSColor {
        if roomPosition == nil {
            return UIHelper.systemMessageColorBackground()
        }
        
        switch (roomPosition!) {
        case .Arena:
            return UIHelper.roomColorArena()
        case .StandA:
            return UIHelper.roomColorStandA()
        case .StandB:
            return UIHelper.roomColorStandB()
        case .StandC:
            return UIHelper.roomColorStandC()
        case .StandD:
            return UIHelper.roomColorStandD()
        case .StandE:
            return UIHelper.roomColorStandE()
        case .StandF:
            return UIHelper.roomColorStandF()
        case .StandG:
            return UIHelper.roomColorStandG()
        case .StandH:
            return UIHelper.roomColorStandH()
        case .StandI:
            return UIHelper.roomColorStandI()
        case .StandJ:
            return UIHelper.roomColorStandJ()
        }
    }
    
    private func stringForRoomPosition(roomPosition: RoomPosition?) -> String {
        guard let roomPosition = roomPosition else {
            return ""
        }

        return roomPosition.shortLabel() + ":"
    }
    
    private func commentNoString(commentNo: Int?) -> String {
        guard let commentNo = commentNo else {
            return ""
        }

        return String(commentNo).numberStringWithSeparatorComma()!
    }
    
    private func setFontSize(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        roomPositionLabel.font = NSFont.systemFontOfSize(size)
        commentNoLabel.font = NSFont.systemFontOfSize(size)
    }
}