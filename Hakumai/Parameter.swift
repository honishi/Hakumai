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
    static let SessionManagement = "SessionManagement"
    static let ShowIfseetnoCommands = "ShowHbIfseetnoCommands"
    static let EnableCommentSpeech = "EnableCommentSpeech"
    
    // mute
    static let EnableMuteUserIds = "EnableMuteUserIds"
    static let EnableMuteWords = "EnableMuteWords"
    static let MuteUserIds = "MuteUserIds"
    static let MuteWords = "MuteWords"
    
    // misc
    static let LastLaunchedApplicationVersion = "LastLaunchedApplicationVersion"
    static let AlwaysOnTop = "AlwaysOnTop"
    static let CommentAnonymously = "CommentAnonymously"
    static let FontSize = "FontSize"
}

// session management
enum SessionManagementType: Int {
    case login = 1000
    case chrome = 1001
    case safari = 1002
}

// keychain
struct KeyChainLoginName {
    static let MailAddress = "MailAddress"
    static let Password = "Password"
}

// dictionary keys in MuteUserIds array objects
struct MuteUserIdKey {
    static let UserId = "UserId"
}

// dictionary keys in MuteUserWords array objects
struct MuteUserWordKey {
    static let Word = "Word"
    // static let EnableRegexp = "EnableRegexp"
}
