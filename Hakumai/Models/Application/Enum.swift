//
//  Enum.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

enum RoomPosition: Int, CustomStringConvertible {
    case arena = 0
    case standA, standB, standC, standD, standE, standF, standG, standH, standI, standJ

    var description: String { return "\(rawValue)(\(label()))" }

    // MARK: - Functions
    func previous() -> RoomPosition? {
        guard self != .arena else { return nil }
        return RoomPosition(rawValue: rawValue - 1)
    }

    func next() -> RoomPosition? {
        guard self != .standJ else { return nil }
        return RoomPosition(rawValue: rawValue + 1)
    }

    // swiftlint:disable cyclomatic_complexity
    func label() -> String {
        switch self {
        case .arena:    return "アリーナ"
        case .standA:   return "立ち見1"
        case .standB:   return "立ち見2"
        case .standC:   return "立ち見3"
        case .standD:   return "立ち見4"
        case .standE:   return "立ち見5"
        case .standF:   return "立ち見6"
        case .standG:   return "立ち見7"
        case .standH:   return "立ち見8"
        case .standI:   return "立ち見9"
        case .standJ:   return "立ち見10"
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // swiftlint:disable cyclomatic_complexity
    func shortLabel() -> String {
        switch self {
        case .arena:   return "ア"
        case .standA:  return "1"
        case .standB:  return "2"
        case .standC:  return "3"
        case .standD:  return "4"
        case .standE:  return "5"
        case .standF:  return "6"
        case .standG:  return "7"
        case .standH:  return "8"
        case .standI:  return "9"
        case .standJ:  return "10"
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
}
