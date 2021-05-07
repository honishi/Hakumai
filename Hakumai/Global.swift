//
//  Global.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// global logger
let log = XCGLogger.default

// MARK: Constant value for storyboard contents
let kNibNameRoomPositionTableCellView = "RoomPositionTableCellView"
let kNibNameScoreTableCellView = "ScoreTableCellView"
let kNibNameUserIdTableCellView = "UserIdTableCellView"
let kNibNamePremiumTableCellView = "PremiumTableCellView"

let kRoomPositionColumnIdentifier = "RoomPositionColumn"
let kScoreColumnIdentifier = "ScoreColumn"
let kCommentColumnIdentifier = "CommentColumn"
let kUserIdColumnIdentifier = "UserIdColumn"
let kPremiumColumnIdentifier = "PremiumColumn"
let kMailColumnIdentifier = "MailColumn"

// MARK: Common regular expressions
// mail address regular expression based on http://qiita.com/sakuro/items/1eaa307609ceaaf51123
let kRegexpMailAddress = "[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*"
let kRegexpPassword = ".{4,}"

// MARK: font size
let kDefaultFontSize: Float = 13
let kMinimumFontSize: Float = 9
let kMaximumFontSize: Float = 30

// MARK: Common constants
let commonUserAgentKey = "User-Agent"
let commonUserAgentValue = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36"
