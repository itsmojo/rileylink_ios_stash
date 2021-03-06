//
//  PodInfoTests.swift
//  OmniKitTests
//
//  Created by Eelke Jager on 18/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

import XCTest
@testable import OmniKit

class PodInfoTests: XCTestCase {
    func testFullMessage() {
        do {
            // Decode
            let infoResponse = try PodInfoResponse(encodedData: Data(hexadecimalString: "0216020d0000000000ab6a038403ff03860000285708030d0000")!)
            XCTAssertEqual(infoResponse.podInfoResponseSubType, .faultEvents)
            let faultEvent = infoResponse.podInfo as! PodInfoFaultEvent
            XCTAssertEqual(faultEvent.faultAccessingTables, false)
            XCTAssertEqual(faultEvent.logEventErrorType, LogEventErrorCode(rawValue: 2))
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoConfiguredAlertsNoAlerts() {
        // 02DATAOFF 0  1 2  3 4  5 6  7 8  910 1112 1314 1516 1718
        // 02 13 // 01 XXXX VVVV VVVV VVVV VVVV VVVV VVVV VVVV VVVV
        // 02 13 // 01 0000 0000 0000 0000 0000 0000 0000 0000 0000
        do {
            // Decode
            let decoded = try PodInfoConfiguredAlerts(encodedData: Data(hexadecimalString: "01000000000000000000000000000000000000")!)
            XCTAssertEqual(.configuredAlerts, decoded.podInfoType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoConfiguredAlertsSuspendStillActive() {
        // 02DATAOFF 0  1 2  3 4  5 6  7 8  910 1112 1314 1516 1718
        // 02 13 // 01 XXXX VVVV VVVV VVVV VVVV VVVV VVVV VVVV VVVV
        // 02 13 // 01 0000 0000 0000 0000 0000 0000 0bd7 0c40 0000 // real alert value after 2 hour suspend
        // 02 13 // 01 0000 0102 0304 0506 0708 090a 0bd7 0c40 0000 // used as a tester to find each alarm
        do {
            // Decode
            let decoded = try PodInfoConfiguredAlerts(encodedData: Data(hexadecimalString: "010000000000000000000000000bd70c400000")!)
            XCTAssertEqual(.configuredAlerts, decoded.podInfoType)
            XCTAssertEqual(.beepBeepBeep, decoded.alertsActivations[5].beepType)
            XCTAssertEqual(11, decoded.alertsActivations[5].timeFromPodStart) // in minutes
            XCTAssertEqual(10.75, decoded.alertsActivations[5].unitsLeft) //, accuracy: 1)
            XCTAssertEqual(.beeeeeep, decoded.alertsActivations[6].beepType)
            XCTAssertEqual(12, decoded.alertsActivations[6].timeFromPodStart) // in minutes
            XCTAssertEqual(3.2, decoded.alertsActivations[6].unitsLeft) //, accuracy: 1)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoConfiguredAlertsReplacePodAfter3DaysAnd8Hours() {
        // 02DATAOFF 0  1 2  3 4  5 6  7 8  910 1112 1314 1516 1718
        // 02 13 // 01 XXXX VVVV VVVV VVVV VVVV VVVV VVVV VVVV VVVV
        // 02 13 // 01 0000 0000 0000 0000 0000 0000 0000 0000 10e1
        do {
            let decoded = try PodInfoConfiguredAlerts(encodedData: Data(hexadecimalString: "010000000000000000000000000000000010e1")!)
            XCTAssertEqual(.configuredAlerts, decoded.podInfoType)
            XCTAssertEqual(.bipBipBipbipBipBip, decoded.alertsActivations[7].beepType)
            XCTAssertEqual(16, decoded.alertsActivations[7].timeFromPodStart) // in 2 hours steps
            XCTAssertEqual(11.25, decoded.alertsActivations[7].unitsLeft, accuracy: 1)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoConfiguredAlertsReplacePodAfterReservoirEmpty() {
        // 02DATAOFF 0  1 2  3 4  5 6  7 8  910 1112 1314 1516 1718
        // 02 13 // 01 XXXX VVVV VVVV VVVV VVVV VVVV VVVV VVVV VVVV
        // 02 13 // 01 0000 0000 0000 1285 0000 11c7 0000 0000 119c
        do {
            let decoded = try PodInfoConfiguredAlerts(encodedData: Data(hexadecimalString: "010000000000001285000011c700000000119c")!)
            XCTAssertEqual(.configuredAlerts, decoded.podInfoType)
            XCTAssertEqual(.bipBeepBipBeepBipBeepBipBeep, decoded.alertsActivations[2].beepType)
            XCTAssertEqual(18, decoded.alertsActivations[2].timeFromPodStart) // in 2 hours steps
            XCTAssertEqual(6.6, decoded.alertsActivations[2].unitsLeft, accuracy: 1)
            XCTAssertEqual(.beep, decoded.alertsActivations[4].beepType)
            XCTAssertEqual(17, decoded.alertsActivations[4].timeFromPodStart) // in 2 hours steps
            XCTAssertEqual(9.95, decoded.alertsActivations[4].unitsLeft, accuracy: 2)
            XCTAssertEqual(.bipBipBipbipBipBip, decoded.alertsActivations[7].beepType)
            XCTAssertEqual(17, decoded.alertsActivations[7].timeFromPodStart) // in 2 hours steps
            XCTAssertEqual(7.8, decoded.alertsActivations[7].unitsLeft, accuracy: 1)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoConfiguredAlertsReplacePod() {
        // 02DATAOFF 0  1 2  3 4  5 6  7 8  910 1112 1314 1516 1718
        // 02 13 // 01 XXXX VVVV VVVV VVVV VVVV VVVV VVVV VVVV VVVV
        // 02 13 // 01 0000 0000 0000 1284 0000 0000 0000 0000 10e0
        do {
            let decoded = try PodInfoConfiguredAlerts(encodedData: Data(hexadecimalString: "010000000000001284000000000000000010e0")!)
            XCTAssertEqual(.configuredAlerts, decoded.podInfoType)
            XCTAssertEqual(.bipBeepBipBeepBipBeepBipBeep, decoded.alertsActivations[2].beepType)
            XCTAssertEqual(18, decoded.alertsActivations[2].timeFromPodStart) // in 2 hours steps
            XCTAssertEqual(6.6, decoded.alertsActivations[2].unitsLeft, accuracy: 1)
            XCTAssertEqual(.bipBipBipbipBipBip, decoded.alertsActivations[7].beepType)
            XCTAssertEqual(16, decoded.alertsActivations[7].timeFromPodStart) // in 2 hours steps
            XCTAssertEqual(11.2, decoded.alertsActivations[7].unitsLeft, accuracy: 1)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoNoFaultAlerts() {
        // 02DATAOFF 0  1  2  3 4  5  6 7  8  910 1112 1314 15 16 17 18 19 2021
        // 02 16 // 02 0J 0K LLLL MM NNNN PP QQQQ RRRR SSSS TT UU VV WW 0X YYYY
        // 02 16 // 02 08 01 0000 0a 0038 00 0000 03ff 0087 00 00 00 95 ff 0000
        do {
            // Decode
            let decoded = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "02080100000a003800000003ff008700000095ff0000")!)
            XCTAssertEqual(.faultEvents, decoded.podInfoType)
            XCTAssertEqual(.aboveFiftyUnits, decoded.podProgressStatus)
            XCTAssertEqual(.normal, decoded.deliveryStatus)
            XCTAssertEqual(0000, decoded.bolusNotDelivered)
            XCTAssertEqual(0x0a, decoded.podMessageCounter)
            XCTAssertEqual(.noFaults, decoded.faultEventCode.faultType)
            XCTAssertEqual(0000, decoded.faultEventTimeSinceActivation)
            XCTAssertEqual(nil, decoded.reservoirLevel)
            XCTAssertEqual(8100, decoded.timeActive)
            XCTAssertEqual("02:15", decoded.timeActive.stringValue)
            XCTAssertEqual(0, decoded.unacknowledgedAlerts.rawValue)
            XCTAssertEqual(false, decoded.faultAccessingTables)
            XCTAssertEqual(LogEventErrorCode(rawValue: 0), decoded.logEventErrorType)
            XCTAssertEqual(.inactive, decoded.previousPodProgressStatus)
            XCTAssertEqual(2, decoded.receiverLowGain)
            XCTAssertEqual(21, decoded.radioRSSI)
            XCTAssertEqual(.inactive, decoded.previousPodProgressStatus)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testPodInfoDeliveryErrorDuringPriming() {
        // 02DATAOFF 0  1  2  3 4  5  6 7  8  910 1112 1314 15 16 17 18 19 2021
        // 02 16 // 02 0J 0K LLLL MM NNNN PP QQQQ RRRR SSSS TT UU VV WW 0X YYYY
        // 02 16 // 02 0f 00 0000 09 0034 5c 0001 03ff 0001 00 00 05 ae 05 6029
        do {
            // Decode
            let decoded = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020f0000000900345c000103ff0001000005ae056029")!)
            XCTAssertEqual(.faultEvents, decoded.podInfoType)
            XCTAssertEqual(.inactive, decoded.podProgressStatus)
            XCTAssertEqual(.suspended, decoded.deliveryStatus)
            XCTAssertEqual(0000, decoded.bolusNotDelivered)
            XCTAssertEqual(9, decoded.podMessageCounter)
            XCTAssertEqual(.primeOpenCountTooLow, decoded.faultEventCode.faultType)
            XCTAssertEqual(60, decoded.faultEventTimeSinceActivation)
            XCTAssertEqual(nil, decoded.reservoirLevel)
            XCTAssertEqual(TimeInterval(minutes: 1), decoded.timeActive)
            XCTAssertEqual(60, decoded.timeActive)
            XCTAssertEqual(00, decoded.unacknowledgedAlerts.rawValue)
            XCTAssertEqual(false, decoded.faultAccessingTables)
            XCTAssertEqual(LogEventErrorCode(rawValue: 0), decoded.logEventErrorType)
            XCTAssertEqual(.primingCompleted, decoded.logEventErrorPodProgressStatus)
            XCTAssertEqual(2, decoded.receiverLowGain)
            XCTAssertEqual(46, decoded.radioRSSI)
            XCTAssertEqual(.primingCompleted, decoded.previousPodProgressStatus)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testPodInfoDuringPriming() {
        // Needle cap accidentally removed before priming started leaking and gave error:
        // 02DATAOFF 0  1  2  3 4  5  6 7  8  910 1112 1314 15 16 17 18 19 2021
        // 02 16 // 02 0J 0K LLLL MM NNNN PP QQQQ RRRR SSSS TT UU VV WW 0X YYYY
        // 02 16 // 02 0d 00 0000 06 0000 8f 0000 03ff 0000 00 00 03 a2 03 86a0
        do {
            // Decode
            let decoded = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020d0000000600008f000003ff0000000003a20386a0")!)
            XCTAssertEqual(.faultEvents, decoded.podInfoType)
            XCTAssertEqual(.faultEventOccurred, decoded.podProgressStatus)
            XCTAssertEqual(.suspended, decoded.deliveryStatus)
            XCTAssertEqual(0, decoded.bolusNotDelivered, accuracy: 0.01)
            XCTAssertEqual(6, decoded.podMessageCounter)
            XCTAssertEqual(.command1AParseUnexpectedFailed, decoded.faultEventCode.faultType)
            XCTAssertEqual(0000*60, decoded.faultEventTimeSinceActivation)
            XCTAssertEqual(nil, decoded.reservoirLevel)
            XCTAssertEqual(0, decoded.timeActive) // timeActive converts minutes to seconds
            XCTAssertEqual(0, decoded.unacknowledgedAlerts.rawValue)
            XCTAssertEqual(false, decoded.faultAccessingTables)
            XCTAssertEqual(LogEventErrorCode(rawValue: 0), decoded.logEventErrorType)
            XCTAssertEqual(.pairingCompleted, decoded.logEventErrorPodProgressStatus)
            XCTAssertEqual(2, decoded.receiverLowGain)
            XCTAssertEqual(34, decoded.radioRSSI)
            XCTAssertEqual(.pairingCompleted, decoded.previousPodProgressStatus)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testPodInfoFaultEventErrorShuttingDown() {
        // Failed Pod after 1 day, 18+ hours of live use shortly after installing new omniloop.
        // 02DATAOFF 0  1  2  3 4  5  6 7  8  910 1112 1314 15 16 17 18 19 2021
        // 02 16 // 02 0J 0K LLLL MM NNNN PP QQQQ RRRR SSSS TT UU VV WW 0X YYYY
        // 02 16 // 02 0d 00 0000 04 07f2 86 09ff 03ff 0a02 00 00 08 23 08 0000
        do {
            // Decode
            let decoded = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020d0000000407f28609ff03ff0a0200000823080000")!)
            XCTAssertEqual(.faultEvents, decoded.podInfoType)
            XCTAssertEqual(.faultEventOccurred, decoded.podProgressStatus)
            XCTAssertEqual(.suspended, decoded.deliveryStatus)
            XCTAssertEqual(0, decoded.bolusNotDelivered)
            XCTAssertEqual(4, decoded.podMessageCounter)
            XCTAssertEqual(101.7, decoded.totalInsulinDelivered, accuracy: 0.01)
            XCTAssertEqual(.basalOverInfusionPulse, decoded.faultEventCode.faultType)
            XCTAssertEqual(0, decoded.unacknowledgedAlerts.rawValue)
            XCTAssertEqual(2559 * 60, decoded.faultEventTimeSinceActivation) //09ff
            XCTAssertEqual("1 day plus 18:39", decoded.faultEventTimeSinceActivation?.stringValue)
            XCTAssertEqual(nil, decoded.reservoirLevel)
            XCTAssertEqual(false, decoded.faultAccessingTables)
            XCTAssertEqual(LogEventErrorCode(rawValue: 0), decoded.logEventErrorType)
            XCTAssertEqual(.aboveFiftyUnits, decoded.logEventErrorPodProgressStatus)
            XCTAssertEqual(0, decoded.receiverLowGain)
            XCTAssertEqual(35, decoded.radioRSSI)
            XCTAssertEqual(.aboveFiftyUnits, decoded.previousPodProgressStatus)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoFaultEventLogEventErrorCode2() {
        // 02DATAOFF 0  1  2  3 4  5  6 7  8  910 1112 1314 15 16 17 18 19 2021
        // 02 16 // 02 0J 0K LLLL MM NNNN PP QQQQ RRRR SSSS TT UU VV WW 0X YYYY
        // 02 16 // 02 0d 00 0000 04 07eb 6a 0e0c 03ff 0e14 00 00 28 17 08 0000
        do {
            // Decode
            let decoded = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020d0000000407eb6a0e0c03ff0e1400002817080000")!)
            XCTAssertEqual(.faultEvents, decoded.podInfoType)
            XCTAssertEqual(.faultEventOccurred, decoded.podProgressStatus)
            XCTAssertEqual(.suspended, decoded.deliveryStatus)
            XCTAssertEqual(0, decoded.bolusNotDelivered)
            XCTAssertEqual(4, decoded.podMessageCounter)
            XCTAssertEqual(101.35, decoded.totalInsulinDelivered, accuracy: 0.01)
            XCTAssertEqual(.occlusionCheckAboveThreshold, decoded.faultEventCode.faultType)
            XCTAssertEqual(0, decoded.unacknowledgedAlerts.rawValue)
            XCTAssertEqual(3596 * 60, decoded.faultEventTimeSinceActivation) //09ff
            XCTAssertEqual("2 days plus 11:56", decoded.faultEventTimeSinceActivation?.stringValue)
            XCTAssertEqual(nil, decoded.reservoirLevel)
            XCTAssertEqual(false, decoded.faultAccessingTables)
            XCTAssertEqual(.internal2BitVariableSetAndManipulatedInMainLoopRoutines2, decoded.logEventErrorType.eventErrorType)
            XCTAssertEqual(.aboveFiftyUnits, decoded.logEventErrorPodProgressStatus)
            XCTAssertEqual(0, decoded.receiverLowGain)
            XCTAssertEqual(23, decoded.radioRSSI)
            XCTAssertEqual(.aboveFiftyUnits, decoded.previousPodProgressStatus)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoFaultEventIsulinNotDelivered() {
        // 02DATAOFF 0  1  2  3 4  5  6 7  8  910 1112 1314 15 16 17 18 19 2021
        // 02 16 // 02 0J 0K LLLL MM NNNN PP QQQQ RRRR SSSS TT UU VV WW 0X YYYY
        // 02 16 // 02 0f 00 0001 02 00ec 6a 0268 03ff 026b 00 00 28 a7 08 2023
        do {
            // Decode
            let decoded = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020f0000010200ec6a026803ff026b000028a7082023")!)
            XCTAssertEqual(.faultEvents, decoded.podInfoType)
            XCTAssertEqual(.inactive, decoded.podProgressStatus)
            XCTAssertEqual(.suspended, decoded.deliveryStatus)
            XCTAssertEqual(0.05, decoded.bolusNotDelivered)
            XCTAssertEqual(2, decoded.podMessageCounter)
            XCTAssertEqual(11.8, decoded.totalInsulinDelivered, accuracy: 0.01)
            XCTAssertEqual(.occlusionCheckAboveThreshold, decoded.faultEventCode.faultType)
            XCTAssertEqual(0, decoded.unacknowledgedAlerts.rawValue)
            XCTAssertEqual(616 * 60, decoded.faultEventTimeSinceActivation) //09ff
            XCTAssertEqual("10:16", decoded.faultEventTimeSinceActivation?.stringValue)
            XCTAssertEqual(nil, decoded.reservoirLevel)
            XCTAssertEqual(false, decoded.faultAccessingTables)
            XCTAssertEqual(.internal2BitVariableSetAndManipulatedInMainLoopRoutines2, decoded.logEventErrorType.eventErrorType)
            XCTAssertEqual(.aboveFiftyUnits, decoded.logEventErrorPodProgressStatus)
            XCTAssertEqual(2, decoded.receiverLowGain)
            XCTAssertEqual(39, decoded.radioRSSI)
            XCTAssertEqual(.aboveFiftyUnits, decoded.previousPodProgressStatus)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoDataLog() {
        // 02DATAOFF 0  1  2 3  4 5  6  7  8
        // 02 LL // 03 PP QQQQ SSSS 04 3c NNNNNNNN NNNNNNNN NNNNNNNN
        // 02 14 // 03 5F 0001 0002 04 3c 01020304 05060708 090a0b0c
        do {
            let decoded = try PodInfoDataLog(encodedData: Data(hexadecimalString: "035F00010002043c0102030405060708090a0b0c")!)
            XCTAssertEqual(.dataLog, decoded.podInfoType)
            XCTAssertEqual(.checkVoltageFailure, decoded.faultEventCode.faultType)
            XCTAssertEqual(0001*60, decoded.timeFaultEvent)
            XCTAssertEqual(0002*60, decoded.timeActivation)
            XCTAssertEqual(3, decoded.nEntries)
            XCTAssertEqual(0x01020304, decoded.pulseLog[0])
            XCTAssertEqual(0x05060708, decoded.pulseLog[1])
            XCTAssertEqual(0x090a0b0c, decoded.pulseLog[2])
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoFault() {
        // 02DATAOFF 0  1  2 3  4 5 6 7  8 91011 1213141516
        // 02 11 // 05 PP QQQQ 00000000 00000000 MMDDYYHHMM
        // 02 11 // 05 92 0001 00000000 00000000 091912170e
        // 09-25-18 23:14 int values for datetime
        do {                                            
            // Decode
            let decoded = try PodInfoFault(encodedData: Data(hexadecimalString: "059200010000000000000000091912170e")!)
            XCTAssertEqual(.fault, decoded.podInfoType)
            XCTAssertEqual(.badPumpReq2State, decoded.faultEventCode.faultType)
            XCTAssertEqual(0001*60, decoded.timeActivation)
            let decodedDateTime = decoded.dateTime
            XCTAssertEqual(2018, decodedDateTime.year)
            XCTAssertEqual(09, decodedDateTime.month)
            XCTAssertEqual(25, decodedDateTime.day)
            XCTAssertEqual(23, decodedDateTime.hour)
            XCTAssertEqual(14, decodedDateTime.minute)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testPodInfoPulseLogRecent() {
       //02 cb 50 0086 34212e00 39203100 3c212d00 41203000 44202c00 49212e00 4c212b00 51202f00 54212c00 59203080 5c202d80 61203080 00212e80 05213180 08202f80 0d203280 10202f80 15213180 18202f80 1d213180 20202e80 25213300 28203200 2d213500 30213100 35213400 38213100 3d203500 40203100 45213300 48203000 4d213200 50212f00 55203300 58203080 5d213280 60202f80 01203080 04202c80 09213180 0c213080 11213280 14203180 19213380 1c203180 21203280 24213200 29203500 2c213100 31213400"
        do {
            // Decode
            let decoded = try PodInfoPulseLogRecent(encodedData: Data(hexadecimalString: "50008634212e00392031003c212d004120300044202c0049212e004c212b0051202f0054212c00592030805c202d806120308000212e800521318008202f800d20328010202f801521318018202f801d21318020202e8025213300282032002d2135003021310035213400382131003d2035004020310045213300482030004d21320050212f0055203300582030805d21328060202f800120308004202c80092131800c2130801121328014203180192133801c2031802120328024213200292035002c21310031213400")!)
            XCTAssertEqual(.pulseLogRecent, decoded.podInfoType)
            XCTAssertEqual(134, decoded.indexLastEntry)
            XCTAssertEqual(50, decoded.nEntries)
            XCTAssertEqual(0x34212e00, decoded.pulseLog[0])
            XCTAssertEqual(0x59203080, decoded.pulseLog[9])
            XCTAssertEqual(0x1d213180, decoded.pulseLog[19])
            XCTAssertEqual(0x45213300, decoded.pulseLog[29])
            XCTAssertEqual(0x09213180, decoded.pulseLog[39])
            XCTAssertEqual(0x31213400, decoded.pulseLog[49])
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testPodInfoPulseLogPrevious() {
        //02 cb 51 0032 14602500 19612800 1c612400 21612800 24612500 29612900 2c602600 31602a00 34602600 39612a80 3c612680 41602c80 00602780 05632880 08602580 0d612880 10612580 15612780 18602380 1d602680 20612280 25602700 28612400 2d212800 30202700 35202a00 38202700 3d202a00 40202900 45202c00 48202a00 4d212c00 50212900 55212c00 58212980 5d202b80 60202880 01202d80 04212a80 09202d80 0c212980 11212a80 14212980 1921801c 212a8021 212c8024 202c0029 212f002c 212d0031 20310082
        do {
            // Decode
            let decoded = try PodInfoPulseLogPrevious(encodedData: Data(hexadecimalString: "51003214602500196128001c6124002161280024612500296129002c60260031602a003460260039612a803c61268041602c800060278005632880086025800d6128801061258015612780186023801d6026802061228025602700286124002d2128003020270035202a00382027003d202a004020290045202c0048202a004d212c005021290055212c00582129805d202b806020288001202d8004212a8009202d800c21298011212a80142129801921801c212a8021212c8024202c0029212f002c212d003120310082")!)
            XCTAssertEqual(.pulseLogPrevious, decoded.podInfoType)
            XCTAssertEqual(50, decoded.nEntries)
            XCTAssertEqual(0x14602500, decoded.pulseLog[0])
            XCTAssertEqual(0x39612a80, decoded.pulseLog[9])
            XCTAssertEqual(0x1d602680, decoded.pulseLog[19])
            XCTAssertEqual(0x45202c00, decoded.pulseLog[29])
            XCTAssertEqual(0x09202d80, decoded.pulseLog[39])
            XCTAssertEqual(0x20310082, decoded.pulseLog[49])
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testPodFault12() {
        // 02DATAOFF 0  1  2  3 4  5  6 7  8  910 1112 1314 15 16 17 18 19 2021
        // 02 16 // 02 0J 0K LLLL MM NNNN PP QQQQ RRRR SSSS TT UU VV WW 0X YYYY
        // 02 16 // 02 0d 00 0000 00 0000 12 ffff 03ff 0000 00 00 87 92 07 0000
        do {
            // Decode
            let faultEvent = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020d00000000000012ffff03ff000000008792070000")!)
            XCTAssertEqual(faultEvent.faultAccessingTables, false)
            XCTAssertNil(faultEvent.faultEventTimeSinceActivation)
            
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
}
