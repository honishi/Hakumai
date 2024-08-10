//
//  ProgramProvider.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2024/08/11.
//  Copyright © 2024 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct ProgramProvider {
    // MARK: - Properties
    let programProviderId: String
    let name: String
    let profileUrl: URL
    let icons: Icons

    struct Icons {
        let uri150x150: URL
        let uri50x50: URL
    }
}

extension ProgramProvider: CustomStringConvertible {
    var description: String {
        "ProgramProvider: programProviderId[\(programProviderId)] name[\(name)] " +
            "profileUrl[\(profileUrl)]"
    }
}
