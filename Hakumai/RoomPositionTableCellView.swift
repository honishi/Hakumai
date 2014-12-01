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
    
    var roomPosition: RoomPosition? = nil {
        didSet {
            self.roomPositionLabel.stringValue = self.stringForRoomPosition(self.roomPosition)
            self.coloredView.fillColor = self.colorForRoomPosition(self.roomPosition)
        }
    }
    
    var commentNo: Int? = nil {
        didSet {
            self.commentNoLabel.stringValue = self.commentNoString(self.commentNo)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Internal Functions
    func colorForRoomPosition(roomPosition: RoomPosition?) -> NSColor {
        if roomPosition == nil {
            return ColorScheme.systemMessageColorBackground()
        }
        
        switch (roomPosition!) {
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
    
    func stringForRoomPosition(roomPosition: RoomPosition?) -> String {
        var string = ""

        if let unwrapped = roomPosition {
            string = unwrapped.shortLabel() + ":"
        }
        
        return string
    }
    
    func commentNoString(commentNo: Int?) -> String {
        var string = ""
        
        if let unwrapped = commentNo {
            string = String(unwrapped).numberStringWithSeparatorComma()!
        }
        
        return string
    }
}