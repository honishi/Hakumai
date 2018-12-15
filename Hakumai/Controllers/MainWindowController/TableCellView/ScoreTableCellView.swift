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

final class ScoreTableCellView: NSTableCellView {
    @IBOutlet weak var coloredView: ColoredView!
    @IBOutlet weak var scoreLabel: NSTextField!

    var chat: Chat? = nil {
        didSet {
            coloredView.fillColor = color(forChatScore: chat)
            scoreLabel.stringValue = string(forChatScore: chat)
        }
    }

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }
}

extension ScoreTableCellView {
    func color(forChatScore chat: Chat?) -> NSColor {
        // println("\(score)")
        guard let chat = chat, let score = chat.score else { return UIHelper.systemMessageColorBackground() }

        if chat.isSystemComment {
            return UIHelper.systemMessageColorBackground()
        }

        switch score {
        case kScoreThresholdGreen:
            return UIHelper.scoreColorGreen()
        case kScoreThresholdLightGreen + 1 ... kScoreThresholdGreen:
            return UIHelper.scoreColorLightGreen()
        case kScoreThresholdYellow + 1 ... kScoreThresholdLightGreen:
            return UIHelper.scoreColorYellow()
        case kScoreThresholdOrange + 1 ... kScoreThresholdYellow:
            return UIHelper.scoreColorOrange()
        default:
            return UIHelper.scoreColorRed()
        }
    }

    func string(forChatScore chat: Chat?) -> String {
        guard let score = chat?.score,
            let withComma = String(score).numberStringWithSeparatorComma() else {
                return ""
        }
        return withComma
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        scoreLabel.font = NSFont.systemFont(ofSize: size)
    }
}
