//
//  ScoreTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/25/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

let kScoreThresholdGreen = 0
let kScoreThresholdLightGreen = -1000
let kScoreThresholdYellow = -4800
let kScoreThresholdOrange = -10000

class ScoreTableCellView : NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var scoreLabel: NSTextField!
    
    var score: Int = 0 {
        didSet {
            let color = self.colorForScore(self.score)
            self.coloredView.fillColor = color
            
            let scoreString = String(self.score).numberStringWithSeparatorComma()!
            self.scoreLabel.stringValue = scoreString
        }
    }

    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Internal Functions
    func colorForScore(score: Int) -> NSColor {
        // println("\(self.score)")
        
        if score == kScoreThresholdGreen {
            return ColorScheme.greenScoreColor()
        }
        else if kScoreThresholdLightGreen < score && score < kScoreThresholdGreen {
            return ColorScheme.lightGreenScoreColor()
        }
        else if kScoreThresholdYellow < score && score <= kScoreThresholdLightGreen {
            return ColorScheme.yellowScoreColor()
        }
        else if kScoreThresholdOrange < score && score <= kScoreThresholdYellow {
            return ColorScheme.orangeScoreColor()
        }
        
        return ColorScheme.redScoreColor()
    }
}