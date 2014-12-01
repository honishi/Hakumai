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

class ScoreTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var scoreLabel: NSTextField!
    
    var score: Int? = nil {
        didSet {
            self.coloredView.fillColor = self.colorForScore(self.score)
            self.scoreLabel.stringValue = self.stringForScore(self.score)
        }
    }

    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Internal Functions
    func colorForScore(score: Int?) -> NSColor {
        // println("\(self.score)")
        
        if score == nil {
            return ColorScheme.systemMessageColorBackground()
        }
        
        if score == kScoreThresholdGreen {
            return ColorScheme.scoreColorGreen()
        }
        else if kScoreThresholdLightGreen < score && score < kScoreThresholdGreen {
            return ColorScheme.scoreColorLightGreen()
        }
        else if kScoreThresholdYellow < score && score <= kScoreThresholdLightGreen {
            return ColorScheme.scoreColorYellow()
        }
        else if kScoreThresholdOrange < score && score <= kScoreThresholdYellow {
            return ColorScheme.scoreColorOrange()
        }
        
        return ColorScheme.scoreColorRed()
    }
    
    func stringForScore(score: Int?) -> String {
        var string = ""
        
        if let unwrapped = score {
            string = String(unwrapped).numberStringWithSeparatorComma()!
        }
        
        return string
    }
}