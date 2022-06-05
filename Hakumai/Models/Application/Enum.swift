//
//  Enum.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

enum BrowserType {
    case chrome, safari
}

enum RoomPosition: Int, CaseIterable {
    case arena = 0
    case storeA, storeB, storeC, storeD, storeE, storeF, storeG, storeH, storeI, storeJ

    // swiftlint:disable cyclomatic_complexity
    func label() -> String {
        switch self {
        case .arena:    return "アリーナ"
        case .storeA:   return "Store1"
        case .storeB:   return "Store2"
        case .storeC:   return "Store3"
        case .storeD:   return "Store4"
        case .storeE:   return "Store5"
        case .storeF:   return "Store6"
        case .storeG:   return "Store7"
        case .storeH:   return "Store8"
        case .storeI:   return "Store9"
        case .storeJ:   return "Store10"
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // swiftlint:disable cyclomatic_complexity
    func shortLabel() -> String {
        switch self {
        case .arena:   return "ア"
        case .storeA:  return "1"
        case .storeB:  return "2"
        case .storeC:  return "3"
        case .storeD:  return "4"
        case .storeE:  return "5"
        case .storeF:  return "6"
        case .storeG:  return "7"
        case .storeH:  return "8"
        case .storeI:  return "9"
        case .storeJ:  return "10"
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

enum Premium: Int, CustomStringConvertible {
    case ippan = 0
    case premium = 1
    case system = 2     // '/disconnect'
    case caster = 3
    case `operator` = 6
    case bsp = 7
    case ippanTransparent = 24

    var description: String { return "\(rawValue)(\(label()))" }

    func label() -> String {
        switch self {
        case .ippan:    return "一般"
        case .premium:  return "プレミアム"
        case .system:   return "システム"
        case .caster:   return "放送主"
        case .operator: return "運営"
        case .bsp:      return "BSP"
        case .ippanTransparent: return "一般 (透明)"
        }
    }

    var isSystem: Bool { [.system, .caster, .operator].contains(self) }
    var isUser: Bool { [.ippan, .premium, .ippanTransparent].contains(self) }
}
