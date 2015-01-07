//
//  ScoreTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let kScoreThresholdGreen = 0
private let kScoreThresholdLightGreen = -1000
private let kScoreThresholdYellow = -4800
private let kScoreThresholdOrange = -10000

class ScoreTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var scoreLabel: NSTextField!

    var chat: Chat? = nil {
        didSet {
            self.coloredView.fillColor = self.colorForChatScore(self.chat)
            self.scoreLabel.stringValue = self.stringForChatScore(self.chat)
        }
    }

    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Internal Functions
    func colorForChatScore(chat: Chat?) -> NSColor {
        // println("\(self.score)")
        if chat == nil {
            return UIHelper.systemMessageColorBackground()
        }
        
        if chat!.premium == .System || chat!.premium == .Caster || chat!.premium == .Operator {
            return UIHelper.systemMessageColorBackground()
        }
        
        if chat!.score == kScoreThresholdGreen {
            return UIHelper.scoreColorGreen()
        }
        else if kScoreThresholdLightGreen < chat!.score && chat!.score < kScoreThresholdGreen {
            return UIHelper.scoreColorLightGreen()
        }
        else if kScoreThresholdYellow < chat!.score && chat!.score <= kScoreThresholdLightGreen {
            return UIHelper.scoreColorYellow()
        }
        else if kScoreThresholdOrange < chat!.score && chat!.score <= kScoreThresholdYellow {
            return UIHelper.scoreColorOrange()
        }
        
        return UIHelper.scoreColorRed()
    }
    
    func stringForChatScore(chat: Chat?) -> String {
        var string = ""
        
        if let unwrapped = chat?.score {
            string = String(unwrapped).numberStringWithSeparatorComma()!
        }
        
        return string
    }
}