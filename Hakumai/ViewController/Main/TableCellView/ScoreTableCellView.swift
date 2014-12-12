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
            return UIHelper.systemMessageColorBackground()
        }
        
        if score == kScoreThresholdGreen {
            return UIHelper.scoreColorGreen()
        }
        else if kScoreThresholdLightGreen < score && score < kScoreThresholdGreen {
            return UIHelper.scoreColorLightGreen()
        }
        else if kScoreThresholdYellow < score && score <= kScoreThresholdLightGreen {
            return UIHelper.scoreColorYellow()
        }
        else if kScoreThresholdOrange < score && score <= kScoreThresholdYellow {
            return UIHelper.scoreColorOrange()
        }
        
        return UIHelper.scoreColorRed()
    }
    
    func stringForScore(score: Int?) -> String {
        var string = ""
        
        if let unwrapped = score {
            string = String(unwrapped).numberStringWithSeparatorComma()!
        }
        
        return string
    }
}