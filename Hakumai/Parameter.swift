//
//  Parameter.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// top level parameters
// http://stackoverflow.com/a/26252377
struct Parameters {
    // general
    static let browserInUse = "BrowserInUse"
    static let commentSpeechVolume = "CommentSpeechVolume"

    // mute
    static let enableMuteUserIds = "EnableMuteUserIds"
    static let enableMuteWords = "EnableMuteWords"
    static let muteUserIds = "MuteUserIds"
    static let muteWords = "MuteWords"

    // misc
    static let lastLaunchedApplicationVersion = "LastLaunchedApplicationVersion"
    static let alwaysOnTop = "AlwaysOnTop"
    static let commentAnonymously = "CommentAnonymously"
    static let fontSize = "FontSize"
    static let enableDebugMessage = "EnableDebugMessage"
}

// session management
enum BrowserInUseType: Int {
    case chrome = 1001
    case safari = 1002
}

// dictionary keys in MuteUserIds array objects
struct MuteUserIdKey {
    static let userId = "UserId"
}

// dictionary keys in MuteUserWords array objects
struct MuteUserWordKey {
    static let word = "Word"
    // static let EnableRegexp = "EnableRegexp"
}
