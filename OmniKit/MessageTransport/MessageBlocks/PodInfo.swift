//
//  PodInfoResponseSubType.swift
//  OmniKit
//
//  Created by Eelke Jager on 15/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol PodInfo {
    init(encodedData: Data) throws
    var podInfoType: PodInfoResponseSubType { get }
    var data: Data { get }
    
}

public enum PodInfoResponseSubType: UInt8, Equatable {
    case normal                      = 0x00 // returns the normal (single packet) StatusResponse
    case configuredAlerts            = 0x01 // returns information about the configured alerts
    case faultEvents                 = 0x02 // returned for faults and pod info type 2 requests
    case dataLog                     = 0x03 // returns up to the last 60 pulse log entries and other fault info
    case fault                       = 0x05 // returns fault code & time from activation and pod initialization time
    case pulseLogRecent              = 0x50 // returns up to the last 50 entries data from the pulse log
    case pulseLogPrevious            = 0x51 // similar to 0x50, but returns pulse log entries previous to the last 50 entries
    
    public var podInfoType: PodInfo.Type {
        switch self {
        case .normal:
            return StatusResponse.self as! PodInfo.Type
        case .configuredAlerts:
            return PodInfoConfiguredAlerts.self
        case .faultEvents:
            return PodInfoFaultEvent.self
        case .dataLog:
            return PodInfoDataLog.self
        case .fault:
            return PodInfoFault.self
        case .pulseLogRecent:
            return PodInfoPulseLogRecent.self
        case .pulseLogPrevious:
            return PodInfoPulseLogPrevious.self
        }
    }
}
