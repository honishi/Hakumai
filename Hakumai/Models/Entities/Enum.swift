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
            return "立ち見A"
        case .standB:
            return "立ち見B"
        case .standC:
            return "立ち見C"
        case .standD:
            return "立ち見D"
        case .standE:
            return "立ち見E"
        case .standF:
            return "立ち見F"
        case .standG:
            return "立ち見G"
        case .standH:
            return "立ち見H"
        case .standI:
            return "立ち見I"
        case .standJ:
            return "立ち見J"
        }
    }
    
    func shortLabel() -> String {
        // TODO: should replace this if-else clause with switch-clause below.
        // this is damned workaround for complile-time 'segmentation fault 11' issue.
        // http://stackoverflow.com/questions/28696248/segmentation-fault-11-when-building-for-profiling-in-a-swift-enum
        if self == .arena {
            return "ア"
        }
        else if self == .standA {
            return "A"
        }
        else if self == .standB {
            return "B"
        }
        else if self == .standC {
            return "C"
        }
        else if self == .standD {
            return "D"
        }
        else if self == .standE {
            return "E"
        }
        else if self == .standF {
            return "F"
        }
        else if self == .standG {
            return "G"
        }
        else if self == .standH {
            return "H"
        }
        else if self == .standI {
            return "I"
        }
        else if self == .standJ {
            return "J"
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
