//
//  Parameter.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// parameters
// http://stackoverflow.com/a/26252377
struct Parameters {
    // top level parameters
    static let AlwaysOnTop = "AlwaysOnTop"
    static let ShowIfseetnoCommands = "ShowHbIfseetnoCommands"
    static let CommentAnonymously = "CommentAnonymously"
    static let EnableMuteUserIds = "EnableMuteUserIds"
    static let EnableMuteWords = "EnableMuteWords"
    
    // management
    static let LastLaunchedApplicationVersion = "LastLaunchedApplicationVersion"
    
    // mute userids
    static let MuteUserIds = "MuteUserIds"
    static let MuteUserIdKeyUserId = "UserId"
    
    // mute words
    static let MuteWords = "MuteWords"
    static let MuteWordKeyWord = "Word"
    // static let MuteWordKeyEnableRegexp = "EnableRegexp"
}
