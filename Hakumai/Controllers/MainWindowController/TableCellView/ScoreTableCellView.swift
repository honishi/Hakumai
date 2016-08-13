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
            coloredView.fillColor = color(forChatScore: chat)
            scoreLabel.stringValue = string(forChatScore: chat)
        }
    }
    
    var fontSize: CGFloat? {
        didSet {
            set(fontSize: fontSize)
        }
    }
    
    // MARK: - Internal Functions
    private func color(forChatScore chat: Chat?) -> NSColor {
        // println("\(score)")
        if chat == nil {
            return UIHelper.systemMessageColorBackground()
        }
        
        if chat!.isSystemComment {
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
    
    private func string(forChatScore chat: Chat?) -> String {
        var string = ""
        
        if let unwrapped = chat?.score {
            string = String(unwrapped).numberStringWithSeparatorComma()!
        }
        
        return string
    }
    
    private func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        scoreLabel.font = NSFont.systemFont(ofSize: size)
    }
}
