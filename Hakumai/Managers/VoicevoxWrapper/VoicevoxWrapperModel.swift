//
//  VoicevoxWrapperModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/02/07.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct VoicevoxSpeakerResponse: Codable {
    let name: String
    let styles: [VoicevoxSpeakerStyle]
}

struct VoicevoxSpeakerStyle: Codable {
    let id: Int
    let name: String
}
