//
//  PodInfoDataLog.swift
//  OmniKit
//
//  Created by Eelke Jager on 22/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

// type 3 returns some fault info and up to the last 60 pulse log entries
public struct PodInfoDataLog : PodInfo {
    // CMD 1  2  3  4 5  6 7  8  9 10
    // DATA   0  1  2 3  4 5  6  7  8
    // 02 LL 03 PP QQQQ SSSS 04 3c XXXXXXXX ...

    public var podInfoType   : PodInfoResponseSubType = .dataLog
    public let faultEventCode: FaultEventCode // fault code
    public let timeFaultEvent: TimeInterval // fault time since activation
    public let timeActivation: TimeInterval // current time since activation
    public let nEntries      : Int // how many 32-bit pulse entries returned (calculated)
    public let pulseLog      : [UInt32]
    public let data          : Data

    public init(encodedData: Data) throws {
        let logStartByteOffset = 8 // starting byte offset of the pulse log in DATA
        let nLogBytesReturned = encodedData.count - logStartByteOffset
        if encodedData.count < logStartByteOffset || (nLogBytesReturned & 0x3) != 0 {
            throw MessageBlockError.notEnoughData // not enough data to start log or a non-integral # of log entries
        }
        self.podInfoType = PodInfoResponseSubType(rawValue: encodedData[0])!
        self.faultEventCode = FaultEventCode(rawValue: encodedData[1])
        self.timeFaultEvent = TimeInterval(minutes: Double((Int(encodedData[2] & 0b1) << 8) + Int(encodedData[3])))
        self.timeActivation = TimeInterval(minutes: Double((Int(encodedData[4] & 0b1) << 8) + Int(encodedData[5])))
        self.nEntries = nLogBytesReturned / 4
        self.pulseLog = createPulseLog(encodedData: encodedData, logStartByteOffset: logStartByteOffset, nEntries: self.nEntries)
        self.data = encodedData
    }
}
