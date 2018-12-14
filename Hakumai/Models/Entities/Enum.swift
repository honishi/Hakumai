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
    case standA
    case standB
    case standC
    case standD
    case standE
    case standF
    case standG
    case standH
    case standI
    case standJ

    var description: String {
        return "\(rawValue)(\(label()))"
    }

    // MARK: - Functions
    func previous() -> RoomPosition? {
        if self == .arena {
            return nil
        }

        return RoomPosition(rawValue: rawValue - 1)
    }

    func next() -> RoomPosition? {
        if self == .standJ {
            return nil
        }

        return RoomPosition(rawValue: rawValue + 1)
    }

    func label() -> String {
        switch self {
        case .arena:
            return "アリーナ"
        case .standA:
            return "立ち見1"
        case .standB:
            return "立ち見2"
        case .standC:
            return "立ち見3"
        case .standD:
            return "立ち見4"
        case .standE:
            return "立ち見5"
        case .standF:
            return "立ち見6"
        case .standG:
            return "立ち見7"
        case .standH:
            return "立ち見8"
        case .standI:
            return "立ち見9"
        case .standJ:
            return "立ち見10"
        }
    }

    func shortLabel() -> String {
        // TODO: should replace this if-else clause with switch-clause below.
        // this is damned workaround for complile-time 'segmentation fault 11' issue.
        // http://stackoverflow.com/questions/28696248/segmentation-fault-11-when-building-for-profiling-in-a-swift-enum
        if self == .arena {
            return "ア"
        } else if self == .standA {
            return "1"
        } else if self == .standB {
            return "2"
        } else if self == .standC {
            return "3"
        } else if self == .standD {
            return "4"
        } else if self == .standE {
            return "5"
        } else if self == .standF {
            return "6"
        } else if self == .standG {
            return "7"
        } else if self == .standH {
            return "8"
        } else if self == .standI {
            return "9"
        } else if self == .standJ {
            return "10"
        }

        return "?"

        /*
         switch self {
         case .Arena:
         return "ア"
         case .StandA:
         return "A"
         case .StandB:
         return "B"
         case .StandC:
         return "C"
         case .StandD:
         return "D"
         case .StandE:
         return "E"
         case .StandF:
         return "F"
         case .StandG:
         return "G"
         case .StandH:
         return "H"
         case .StandI:
         return "I"
         case .StandJ:
         return "J"
         }
         */
    }
}

enum Premium: Int, CustomStringConvertible {
    case ippan = 0
    case premium = 1
    case system = 2     // '/disconnect'
    case caster = 3
    case `operator` = 6
    case bsp = 7

    var description: String {
        return "\(rawValue)(\(label()))"
    }

    func label() -> String {
        switch self {
        case .ippan:
            return "一般"
        case .premium:
            return "プレミアム"
        case .system:
            return "システム"
        case .caster:
            return "放送主"
        case .operator:
            return "運営"
        case .bsp:
            return "BSP"
        }
    }
}
