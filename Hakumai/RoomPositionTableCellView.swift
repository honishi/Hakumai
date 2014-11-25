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
    
    var roomPosition: RoomPosition = .Arena {
        didSet {
            self.roomPositionLabel.stringValue = self.roomPosition.shortLabel() + ":"
            self.coloredView.fillColor = self.colorForRoomPosition(self.roomPosition)
        }
    }
    
    var commentNo: Int = 0 {
        didSet {
            self.commentNoLabel.stringValue = String(self.commentNo).numberStringWithSeparatorComma()!
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Internal Functions
    func colorForRoomPosition(roomPosition: RoomPosition) -> NSColor {
        switch (roomPosition) {
        case .Arena:
            return ColorScheme.roomColorArena()
        case .StandA:
            return ColorScheme.roomColorStandA()
        case .StandB:
            return ColorScheme.roomColorStandB()
        case .StandC:
            return ColorScheme.roomColorStandC()
        case .StandD:
            return ColorScheme.roomColorStandD()
        case .StandE:
            return ColorScheme.roomColorStandE()
        case .StandF:
            return ColorScheme.roomColorStandF()
        case .StandG:
            return ColorScheme.roomColorStandG()
        case .StandH:
            return ColorScheme.roomColorStandH()
        case .StandI:
            return ColorScheme.roomColorStandI()
        case .StandJ:
            return ColorScheme.roomColorStandJ()
        default:
            break
        }
        
        return NSColor.grayColor()
    }
}