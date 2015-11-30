//
//  Enum.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

enum RoomPosition: Int, CustomStringConvertible {
    case Arena = 0
    case StandA
    case StandB
    case StandC
    case StandD
    case StandE
    case StandF
    case StandG
    case StandH
    case StandI
    case StandJ
    
    var description: String {
        return "\(rawValue)(\(label()))"
    }

    // MARK: - Functions
    func previous() -> RoomPosition? {
        if self == .Arena {
            return nil
        }
        
        return RoomPosition(rawValue: rawValue - 1)
    }
    
    func next() -> RoomPosition? {
        if self == .StandJ {
            return nil
        }
        
        return RoomPosition(rawValue: rawValue + 1)
    }
    
    func label() -> String {
        switch self {
        case .Arena:
            return "アリーナ"
        case .StandA:
            return "立ち見A"
        case .StandB:
            return "立ち見B"
        case .StandC:
            return "立ち見C"
        case .StandD:
            return "立ち見D"
        case .StandE:
            return "立ち見E"
        case .StandF:
            return "立ち見F"
        case .StandG:
            return "立ち見G"
        case .StandH:
            return "立ち見H"
        case .StandI:
            return "立ち見I"
        case .StandJ:
            return "立ち見J"
        }
    }
    
    func shortLabel() -> String {
        // TODO: should replace this if-else clause with switch-clause below.
        // this is damned workaround for complile-time 'segmentation fault 11' issue.
        // http://stackoverflow.com/questions/28696248/segmentation-fault-11-when-building-for-profiling-in-a-swift-enum
        if self == .Arena {
            return "ア"
        }
        else if self == .StandA {
            return "A"
        }
        else if self == .StandB {
            return "B"
        }
        else if self == .StandC {
            return "C"
        }
        else if self == .StandD {
            return "D"
        }
        else if self == .StandE {
            return "E"
        }
        else if self == .StandF {
            return "F"
        }
        else if self == .StandG {
            return "G"
        }
        else if self == .StandH {
            return "H"
        }
        else if self == .StandI {
            return "I"
        }
        else if self == .StandJ {
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
    case Ippan = 0
    case Premium = 1
    case System = 2     // '/disconnect'
    case Caster = 3
    case Operator = 6
    case BSP = 7
    
    var description: String {
        return "\(rawValue)(\(label()))"
    }
    
    func label() -> String {
        switch self {
        case .Ippan:
            return "一般"
        case .Premium:
            return "プレミアム"
        case .System:
            return "システム"
        case .Caster:
            return "放送主"
        case .Operator:
            return "運営"
        case .BSP:
            return "BSP"
        }
    }
}