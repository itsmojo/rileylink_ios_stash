//
//  PodCommsSession.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit
import LoopKit
import os.log

public enum PodCommsError: Error {
    case noPodPaired
    case invalidData
    case noResponse
    case emptyResponse
    case podAckedInsteadOfReturningResponse
    case unexpectedPacketType(packetType: PacketType)
    case unexpectedResponse(response: MessageBlockType)
    case unknownResponseType(rawType: UInt8)
    case invalidAddress(address: UInt32, expectedAddress: UInt32)
    case noRileyLinkAvailable
    case unfinalizedBolus
    case unfinalizedTempBasal
    case nonceResyncFailed
    case podSuspended
    case podFault(fault: PodInfoFaultEvent)
    case commsError(error: Error)
    case commandError(errorCode: UInt8)
    case debugFault(str: String)
    case podChange
    case activationTimeExceeded
    case rssiTooLow
    case rssiTooHigh
}

extension PodCommsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("No pod paired", comment: "Error message shown when no pod is paired")
        case .invalidData:
            return nil
        case .noResponse:
            return LocalizedString("No response from pod", comment: "Error message shown when no response from pod was received")
        case .emptyResponse:
            return LocalizedString("Empty response from pod", comment: "Error message shown when empty response from pod was received")
        case .podAckedInsteadOfReturningResponse:
            return LocalizedString("Pod sent ack instead of response", comment: "Error message shown when pod sends ack instead of response")
        case .unexpectedPacketType:
            return nil
        case .unexpectedResponse:
            return LocalizedString("Unexpected response from pod", comment: "Error message shown when empty response from pod was received")
        case .unknownResponseType:
            return nil
        case .invalidAddress(address: let address, expectedAddress: let expectedAddress):
            return String(format: LocalizedString("Invalid address 0x%x. Expected 0x%x", comment: "Error message for when unexpected address is received (1: received address) (2: expected address)"), address, expectedAddress)
        case .noRileyLinkAvailable:
            return LocalizedString("No RileyLink available", comment: "Error message shown when no response from pod was received")
        case .unfinalizedBolus:
            return LocalizedString("Bolus in progress", comment: "Error message shown when operation could not be completed due to existing bolus in progress")
        case .unfinalizedTempBasal:
            return LocalizedString("Temp basal in progress", comment: "Error message shown when temp basal could not be set due to existing temp basal in progress")
        case .nonceResyncFailed:
            return nil
        case .podSuspended:
            return LocalizedString("Pod is suspended", comment: "Error message action could not be performed because pod is suspended")
        case .podFault(let fault):
            let faultDescription = String(describing: fault.faultEventCode)
            return String(format: LocalizedString("Pod Fault: %1$@", comment: "Format string for pod fault code"), faultDescription)
        case .commsError(let error):
            return error.localizedDescription
        case .commandError(let errorCode):
            return String(format: LocalizedString("Command error %1$u", comment: "Format string for command error code (1: error code number)"), errorCode)
        case .debugFault(let str):
            return str
        case .podChange:
            return LocalizedString("Unexpected pod change", comment: "Format string for unexpected pod change")
        case .activationTimeExceeded:
            return LocalizedString("Activation time exceeded", comment: "Format string for activation time exceeded")
        case .rssiTooLow:
            return LocalizedString("Poor signal strength", comment: "Format string when RileyLink to pod signal strength is poor")
        case .rssiTooHigh:
            return LocalizedString("Signal strength too high", comment: "Format string when RileyLink pod signal strength is too high")
        }
    }
    
//    public var failureReason: String? {
//        return nil
//    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noPodPaired:
            return nil
        case .invalidData:
            return nil
        case .noResponse:
            return LocalizedString("Please try repositioning the pod or the RileyLink", comment: "Recovery suggestion when no response is received from pod")
        case .emptyResponse:
            return nil
        case .podAckedInsteadOfReturningResponse:
            return LocalizedString("Try again", comment: "Recovery suggestion when ack received instead of response")
        case .unexpectedPacketType:
            return nil
        case .unexpectedResponse:
            return nil
        case .unknownResponseType:
            return nil
        case .invalidAddress:
            return LocalizedString("Crosstalk possible. Please move to a new location", comment: "Recovery suggestion when unexpected address received")
        case .noRileyLinkAvailable:
            return LocalizedString("Make sure your RileyLink is nearby and powered on", comment: "Recovery suggestion when no RileyLink is available")
        case .unfinalizedBolus:
            return LocalizedString("Wait for existing bolus to finish, or cancel bolus", comment: "Recovery suggestion when operation could not be completed due to existing bolus in progress")
        case .unfinalizedTempBasal:
            return LocalizedString("Wait for existing temp basal to finish, or suspend to cancel", comment: "Recovery suggestion when operation could not be completed due to existing temp basal in progress")
        case .nonceResyncFailed:
            return nil
        case .podSuspended:
            return LocalizedString("Resume the pod", comment: "Recovery suggestion when pod is suspended")
        case .podFault:
            return nil
        case .commsError:
            return nil
        case .commandError:
            return nil
        case .debugFault:
            return nil
        case .podChange:
            return LocalizedString("Please bring only original pod in range or deactivate original pod", comment: "Recovery suggestion on unexpected pod change")
        case .activationTimeExceeded:
            return nil
        case .rssiTooLow: // occurs when RileyLink is too far from pod for reliable pairing, but can sometimes occur at other distances & positions
            return LocalizedString("Please reposition the RileyLink relative to the pod", comment: "Recovery suggestion when pairing signal strength too low")
        case .rssiTooHigh: // only occurs when RileyLink is too close to the pod for reliable pairing
            return LocalizedString("Please reposition the RileyLink further from the pod", comment: "Recovery suggestion when pairing signal strength too high")
        }
    }
}

public protocol PodCommsSessionDelegate: class {
    func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState)
}

public class PodCommsSession {
    private let useCancelNoneForStatus: Bool = false             // whether to always use a cancel none to get status
    
    public let log = OSLog(category: "PodCommsSession")
    
    private var podState: PodState {
        didSet {
            assertOnSessionQueue()
            delegate.podCommsSession(self, didChange: podState)
        }
    }
    
    private unowned let delegate: PodCommsSessionDelegate
    private var transport: MessageTransport

    init(podState: PodState, transport: MessageTransport, delegate: PodCommsSessionDelegate) {
        self.podState = podState
        self.transport = transport
        self.delegate = delegate
        self.transport.delegate = self
    }

    // Will throw either PodCommsError.podFault or PodCommsError.activationTimeExceeded
    private func throwPodFault(fault: PodInfoFaultEvent) throws {
        if self.podState.fault == nil {
            self.podState.fault = fault // save the first fault returned
        }
        log.error("Pod Fault: %@", String(describing: fault))
        if fault.deliveryStatus == .suspended {
            let now = Date()
            podState.unfinalizedTempBasal?.cancel(at: now)
            podState.unfinalizedBolus?.cancel(at: now, withRemaining: fault.bolusNotDelivered)
        }
        if fault.podProgressStatus == .activationTimeExceeded {
            // avoids a confusing "No fault" error when activation time is exceeded
            throw PodCommsError.activationTimeExceeded
        }
        throw PodCommsError.podFault(fault: fault)
    }

    // pad the given message to be more than one packet using GetStatus sub-messages
    private func padMessage(message: [MessageBlock]) -> [MessageBlock] {
        let packetLen = PacketType.pdm.maxBodyLen()
        let getStatusCommand = GetStatusCommand()
        let getStatusLen = 3

        var paddedMessage = message
        var encodedLen = messageLength(message: message)
        while encodedLen <= packetLen {
            paddedMessage.append(getStatusCommand)
            encodedLen += getStatusLen
        }
        return paddedMessage
    }

    /// Performs a message exchange, handling nonce resync, pod faults
    ///
    /// - Parameters:
    ///   - messageBlocks: The message blocks to send
    ///   - prefixMessage: Optional message block(s) to prefix to messageBlocks
    ///   - appendMessage: Optional message block(s) to append to messageBlocks
    ///   - expectFollowOnMessage: If true, the pod will expect another message within 4 minutes, or will alarm with an 0x33 (51) fault.
    /// - Returns: The received message response
    /// - Throws:
    ///     - PodCommsError.nonceResyncFailed
    ///     - PodCommsError.noResponse
    ///     - PodCommsError.podFault
    ///     - PodCommsError.unexpectedResponse
    ///     - MessageError
    ///     - RileyLinkDeviceError
    func send<T: MessageBlock>(_ messageBlocks: [MessageBlock], prefixMessage: MessageBlock? = nil, appendMessage: MessageBlock? = nil, expectFollowOnMessage: Bool = false) throws -> T {
        
        var triesRemaining = 2  // Retries only happen for nonce resync
        var blocksToSend: [MessageBlock]
        
        if let prefixMessage = prefixMessage {
            blocksToSend = [prefixMessage] + messageBlocks
        } else {
            blocksToSend = messageBlocks
        }
        if let appendMessage = appendMessage {
            blocksToSend.append(appendMessage)
        }

        if blocksToSend.contains(where: { $0 as? NonceResyncableMessageBlock != nil }) {
            podState.advanceToNextNonce()
            let padNonceMessages = false // edit to pad non deactivatePod nonce messages
            if padNonceMessages && messageBlocks[0].blockType != .deactivatePod {
                blocksToSend = padMessage(message: blocksToSend)
            }
        }
        
        let messageNumber = transport.messageNumber

        var sentNonce: UInt32?

        while (triesRemaining > 0) {
            triesRemaining -= 1

            for command in blocksToSend {
                if let nonceBlock = command as? NonceResyncableMessageBlock {
                    sentNonce = nonceBlock.nonce
                    break // N.B. all nonce commands in single message should have the same value
                }
            }

            let message = Message(address: podState.address, messageBlocks: blocksToSend, sequenceNum: messageNumber, expectFollowOnMessage: expectFollowOnMessage)

            let response = try transport.sendMessage(message)
            
            // Simulate fault
            //let podInfoResponse = try PodInfoResponse(encodedData: Data(hexadecimalString: "0216020d0000000000ab6a038403ff03860000285708030d0000")!)
            //let response = Message(address: podState.address, messageBlocks: [podInfoResponse], sequenceNum: message.sequenceNum)

            if let responseMessageBlock = response.messageBlocks[0] as? T {
                log.info("POD Response: %@", String(describing: responseMessageBlock))
                return responseMessageBlock
            }

            if let fault = response.fault {
                try throwPodFault(fault: fault) // always throws
            }

            let responseType = response.messageBlocks[0].blockType
            guard let errorResponse = response.messageBlocks[0] as? ErrorResponse else {
                log.error("Unexpected response: %{public}@", String(describing: response.messageBlocks[0]))
                throw PodCommsError.unexpectedResponse(response: responseType)
            }

            switch errorResponse.errorResponseType {
            case .badNonce(let nonceResyncKey):
                guard let sentNonce = sentNonce else {
                    log.error("Unexpected bad nonce response: %{public}@", String(describing: response.messageBlocks[0]))
                    throw PodCommsError.unexpectedResponse(response: responseType)
                }
                podState.resyncNonce(syncWord: nonceResyncKey, sentNonce: sentNonce, messageSequenceNum: message.sequenceNum)
                log.info("resyncNonce(syncWord: 0x%02x, sentNonce: 0x%04x, messageSequenceNum: %d) -> 0x%04x", nonceResyncKey, sentNonce, message.sequenceNum, podState.currentNonce)
                blocksToSend = blocksToSend.map({ (block) -> MessageBlock in
                    if var resyncableBlock = block as? NonceResyncableMessageBlock {
                        log.info("Replaced old nonce 0x%04x with resync nonce 0x%04x", resyncableBlock.nonce, podState.currentNonce)
                        resyncableBlock.nonce = podState.currentNonce
                        return resyncableBlock
                    }
                    return block
                })
                podState.advanceToNextNonce()
                break
            case .nonretryableError(let errorCode, let faultEventCode, let podProgress):
                log.error("Command error: code %u, %{public}@, pod progress %{public}@", errorCode, String(describing: faultEventCode), String(describing: podProgress))
                throw PodCommsError.commandError(errorCode: errorCode)
            }
        }
        throw PodCommsError.nonceResyncFailed
    }

    // Returns the time interval from now when the prime is expected to finish.
    public func prime() throws -> TimeInterval {
        let primeDuration = TimeInterval(seconds: Pod.primeUnits / Pod.primeDeliveryRate)

        // Can only do the fault config command if we haven't starting priming or the pod will fault!
        if podState.setupProgress == .podConfigured || podState.setupProgress == .addressAssigned {
            // FaultConfigCommand sets internal pod variables to effectively disable $6x faults which occur more often with a 0 TBR
            let _: StatusResponse = try send([FaultConfigCommand(nonce: podState.currentNonce, tab5Sub16: 0, tab5Sub17: 0)])

            // Set up an alert for a reminder beep every 5 minutes for an hour until the setup process finishes as per the PDM
            let finishSetupReminder = PodAlert.finishSetupReminder
            try configureAlerts([finishSetupReminder])
        } else {
            // We started prime, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .priming || status.podProgressStatus == .primingCompleted {
                podState.setupProgress = .priming
                return podState.primeFinishTime?.timeIntervalSinceNow ?? primeDuration
            }
        }

        // Mark 2.6U delivery with 1 second between pulses for prime
        
        let primeFinishTime = Date() + primeDuration
        podState.primeFinishTime = primeFinishTime
        podState.setupProgress = .startingPrime

        let timeBetweenPulses = TimeInterval(seconds: Pod.secondsPerPrimePulse)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: Pod.primeUnits, timeBetweenPulses: timeBetweenPulses)
        let scheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        let bolusExtraCommand = BolusExtraCommand(units: Pod.primeUnits, timeBetweenPulses: timeBetweenPulses)
        let status: StatusResponse = try send([scheduleCommand, bolusExtraCommand])
        podState.updateFromStatusResponse(status)
        podState.setupProgress = .priming
        return primeFinishTime.timeIntervalSinceNow
    }
    
    public func programInitialBasalSchedule(_ basalSchedule: BasalSchedule, scheduleOffset: TimeInterval) throws {
        if podState.setupProgress == .settingInitialBasalSchedule {
            // We started basal schedule programming, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .basalInitialized {
                podState.setupProgress = .initialBasalScheduleSet
                return
            }
        }
        
        podState.setupProgress = .settingInitialBasalSchedule
        // Set basal schedule
        let _ = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset)
        podState.setupProgress = .initialBasalScheduleSet
        podState.finalizedDoses.append(UnfinalizedDose(resumeStartTime: Date(), scheduledCertainty: .certain))
    }

    @discardableResult
    private func configureAlerts(_ alerts: [PodAlert], beepMessage: MessageBlock? = nil) throws -> StatusResponse {
        let configurations = alerts.map { $0.configuration }
        let configureAlerts = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations: configurations)
        let status: StatusResponse = try send([configureAlerts], appendMessage: beepMessage)
        for alert in alerts {
            podState.registerConfiguredAlert(slot: alert.configuration.slot, alert: alert)
        }
        podState.updateFromStatusResponse(status)
        return status
    }

    // emits the specified beep type and sets the completion beep flags
    @discardableResult
    public func beepConfig(beepConfigType: BeepConfigType, basalCompletionBeep: Bool, tempBasalCompletionBeep: Bool, bolusCompletionBeep: Bool) throws -> StatusResponse {
        let beepConfigCommand = BeepConfigCommand(beepConfigType: beepConfigType, basalCompletionBeep: basalCompletionBeep, tempBasalCompletionBeep: tempBasalCompletionBeep, bolusCompletionBeep: bolusCompletionBeep)
        let status: StatusResponse = try send([beepConfigCommand])
        podState.updateFromStatusResponse(status)
        return status
    }

    private func markSetupProgressCompleted(statusResponse: StatusResponse) {
        if (podState.setupProgress != .completed) {
            podState.setupProgress = .completed
            podState.setupUnitsDelivered = statusResponse.insulin // stash the current insulin delivered value as the baseline
            log.info("Total setup units delivered: %@", String(describing: statusResponse.insulin))
        }
    }

    // Returns the time interval from now when the cannula insertion bolus is expected to finish.
    public func insertCannula() throws -> TimeInterval {
        let insertionWait: TimeInterval = .seconds(Pod.cannulaInsertionUnits / Pod.primeDeliveryRate)

        guard let activatedAt = podState.activatedAt else {
            throw PodCommsError.noPodPaired
        }

        if podState.setupProgress == .startingInsertCannula || podState.setupProgress == .cannulaInserting {
            // We started cannula insertion, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            if status.podProgressStatus == .insertingCannula {
                podState.setupProgress = .cannulaInserting
                podState.updateFromStatusResponse(status)
                return insertionWait // Not sure when it started, wait full time to be sure
            }
            if status.podProgressStatus.readyForDelivery {
                markSetupProgressCompleted(statusResponse: status)
                podState.updateFromStatusResponse(status)
                return TimeInterval(0) // Already done; no need to wait
            }
            podState.updateFromStatusResponse(status)
        } else {
            // Configure all the non-optional Pod Alarms
            let expirationTime = activatedAt + Pod.nominalPodLife
            let timeUntilExpirationAdvisory = expirationTime.timeIntervalSinceNow
            let expirationAdvisoryAlarm = PodAlert.expirationAdvisoryAlarm(alarmTime: timeUntilExpirationAdvisory, duration: Pod.expirationAdvisoryWindow)
            let endOfServiceTime = activatedAt + Pod.serviceDuration
            let shutdownImminentAlarm = PodAlert.shutdownImminentAlarm((endOfServiceTime - Pod.endOfServiceImminentWindow).timeIntervalSinceNow)
            try configureAlerts([expirationAdvisoryAlarm, shutdownImminentAlarm])
        }
        
        // Mark 0.5U delivery with 1 second between pulses for cannula insertion

        let timeBetweenPulses = TimeInterval(seconds: Pod.secondsPerPrimePulse)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: Pod.cannulaInsertionUnits, timeBetweenPulses: timeBetweenPulses)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        
        podState.setupProgress = .startingInsertCannula
        let bolusExtraCommand = BolusExtraCommand(units: Pod.cannulaInsertionUnits, timeBetweenPulses: timeBetweenPulses)
        let status2: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
        podState.updateFromStatusResponse(status2)
        
        podState.setupProgress = .cannulaInserting
        return insertionWait
    }

    public func checkInsertionCompleted() throws {
        if podState.setupProgress == .cannulaInserting {
            let response: StatusResponse = try send([GetStatusCommand()])
            if response.podProgressStatus.readyForDelivery {
                markSetupProgressCompleted(statusResponse: response)
            }
            podState.updateFromStatusResponse(response)
        }
    }

    // Throws SetBolusError
    public enum DeliveryCommandResult {
        case success(statusResponse: StatusResponse)
        case certainFailure(error: PodCommsError)
        case uncertainFailure(error: PodCommsError)
    }

    public enum CancelDeliveryResult {
        case success(statusResponse: StatusResponse, canceledDose: UnfinalizedDose?)
        case certainFailure(error: PodCommsError)
        case uncertainFailure(error: PodCommsError)
    }
    
    public func bolus(units: Double, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) -> DeliveryCommandResult {
        
        let timeBetweenPulses = TimeInterval(seconds: Pod.secondsPerBolusPulse)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: units, timeBetweenPulses: timeBetweenPulses)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        
        guard podState.unfinalizedBolus == nil else {
            return DeliveryCommandResult.certainFailure(error: .unfinalizedBolus)
        }
        
        // Between bluetooth and the radio and firmware, about 1.2s on average passes before we start tracking
        let commsOffset = TimeInterval(seconds: -1.5)
        
        let bolusExtraCommand = BolusExtraCommand(units: units, timeBetweenPulses: timeBetweenPulses, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: programReminderInterval)
        do {
            let statusResponse: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date().addingTimeInterval(commsOffset), scheduledCertainty: .certain)
            podState.updateFromStatusResponse(statusResponse)
            return DeliveryCommandResult.success(statusResponse: statusResponse)
        } catch PodCommsError.nonceResyncFailed {
            return DeliveryCommandResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch PodCommsError.commandError(let errorCode) {
            return DeliveryCommandResult.certainFailure(error: PodCommsError.commandError(errorCode: errorCode))
        } catch let error {
            self.log.debug("Uncertain result bolusing")
            // Attempt to verify bolus
            let podCommsError = error as? PodCommsError ?? PodCommsError.commsError(error: error)
            guard let status = try? getStatus() else {
                self.log.debug("Status check failed; could not resolve bolus uncertainty")
                podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), scheduledCertainty: .uncertain)
                return DeliveryCommandResult.uncertainFailure(error: podCommsError)
            }
            if status.deliveryStatus.bolusing {
                self.log.debug("getStatus resolved bolus uncertainty (succeeded)")
                podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date().addingTimeInterval(commsOffset), scheduledCertainty: .certain)
                podState.updateFromStatusResponse(status)
                return DeliveryCommandResult.success(statusResponse: status)
            } else {
                self.log.debug("getStatus resolved bolus uncertainty (failed)")
                podState.updateFromStatusResponse(status)
                return DeliveryCommandResult.certainFailure(error: podCommsError)
            }
        }
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) -> DeliveryCommandResult {
        
        let tempBasalCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, tempBasalRate: rate, duration: duration)
        let tempBasalExtraCommand = TempBasalExtraCommand(rate: rate, duration: duration, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: programReminderInterval)

        guard podState.unfinalizedBolus?.isFinished != false else {
            return DeliveryCommandResult.certainFailure(error: .unfinalizedBolus)
        }

        do {
            let status: StatusResponse = try send([tempBasalCommand, tempBasalExtraCommand])
            podState.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: rate, startTime: Date(), duration: duration, scheduledCertainty: .certain)
            podState.updateFromStatusResponse(status)
            return DeliveryCommandResult.success(statusResponse: status)
        } catch PodCommsError.nonceResyncFailed {
            return DeliveryCommandResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch PodCommsError.commandError(let errorCode) {
            return DeliveryCommandResult.certainFailure(error: PodCommsError.commandError(errorCode: errorCode))
        } catch let error {
            podState.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: rate, startTime: Date(), duration: duration, scheduledCertainty: .uncertain)
            return DeliveryCommandResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }

    @discardableResult
    private func handleCancelDosing(deliveryType: CancelDeliveryCommand.DeliveryType, bolusNotDelivered: Double) -> UnfinalizedDose? {
        var canceledDose: UnfinalizedDose? = nil
        let now = Date()

        if deliveryType.contains(.basal) {
            podState.unfinalizedSuspend = UnfinalizedDose(suspendStartTime: now, scheduledCertainty: .certain)
            podState.suspendState = .suspended(now)
        }

        if let unfinalizedTempBasal = podState.unfinalizedTempBasal,
            let finishTime = unfinalizedTempBasal.finishTime,
            deliveryType.contains(.tempBasal),
            finishTime > now
        {
            podState.unfinalizedTempBasal?.cancel(at: now)
            if !deliveryType.contains(.basal) {
                podState.suspendState = .resumed(now)
            }
            canceledDose = podState.unfinalizedTempBasal
            log.info("Interrupted temp basal: %@", String(describing: canceledDose))
        }

        if let unfinalizedBolus = podState.unfinalizedBolus,
            let finishTime = unfinalizedBolus.finishTime,
            deliveryType.contains(.bolus),
            finishTime > now
        {
            podState.unfinalizedBolus?.cancel(at: now, withRemaining: bolusNotDelivered)
            canceledDose = podState.unfinalizedBolus
            log.info("Interrupted bolus: %@", String(describing: canceledDose))
        }

        return canceledDose
    }
    
    // Cancel beeping can be implemented either using a beepType (single delivery type only) or a beepMessage.
    // Use the beepType method when cancelling all insulin delivery will emit 3 different sets of beeps!
    public func cancelDelivery(deliveryType: CancelDeliveryCommand.DeliveryType, beepType: BeepType, beepMessage: MessageBlock? = nil) -> CancelDeliveryResult {

        let cancelDeliveryCommand = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: deliveryType, beepType: beepType)
        do {
            let status: StatusResponse = try send([cancelDeliveryCommand], appendMessage: beepMessage)

            let canceledDose = handleCancelDosing(deliveryType: deliveryType, bolusNotDelivered: status.bolusNotDelivered)

            podState.updateFromStatusResponse(status)

            return CancelDeliveryResult.success(statusResponse: status, canceledDose: canceledDose)

        } catch PodCommsError.nonceResyncFailed {
            return CancelDeliveryResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch PodCommsError.commandError(let errorCode) {
            return CancelDeliveryResult.certainFailure(error: PodCommsError.commandError(errorCode: errorCode))
        } catch let error {
            podState.unfinalizedSuspend = UnfinalizedDose(suspendStartTime: Date(), scheduledCertainty: .uncertain)
            return CancelDeliveryResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }

    public func testingCommands(beepMessage: MessageBlock? = nil) throws {
        try cancelNone(beepMessage: beepMessage) // reads status & verifies nonce by doing a cancel none
    }
    
    public func setTime(timeZone: TimeZone, basalSchedule: BasalSchedule, date: Date, acknowledgementBeep: Bool, completionBeep: Bool) throws -> StatusResponse {
        let result = cancelDelivery(deliveryType: .all, beepType: .noBeep)
        switch result {
        case .certainFailure(let error):
            throw error
        case .uncertainFailure(let error):
            throw error
        case .success:
            let scheduleOffset = timeZone.scheduleOffset(forDate: date)
            let status = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep)
            return status
        }
    }
    
    public func setBasalSchedule(schedule: BasalSchedule, scheduleOffset: TimeInterval, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) throws -> StatusResponse {

        let basalScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, basalSchedule: schedule, scheduleOffset: scheduleOffset)
        let basalExtraCommand = BasalScheduleExtraCommand.init(schedule: schedule, scheduleOffset: scheduleOffset, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: programReminderInterval)

        do {
            let status: StatusResponse = try send([basalScheduleCommand, basalExtraCommand])
            let now = Date()
            podState.suspendState = .resumed(now)
            podState.unfinalizedResume = UnfinalizedDose(resumeStartTime: now, scheduledCertainty: .certain)
            podState.updateFromStatusResponse(status)
            return status
        } catch PodCommsError.nonceResyncFailed {
            throw PodCommsError.nonceResyncFailed
        } catch PodCommsError.commandError(let errorCode) {
            throw PodCommsError.commandError(errorCode: errorCode)
        } catch let error {
            podState.unfinalizedResume = UnfinalizedDose(resumeStartTime: Date(), scheduledCertainty: .uncertain)
            throw error
        }
    }
    
    public func resumeBasal(schedule: BasalSchedule, scheduleOffset: TimeInterval, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) throws -> StatusResponse {
        
        let status = try setBasalSchedule(schedule: schedule, scheduleOffset: scheduleOffset, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: programReminderInterval)

        podState.suspendState = .resumed(Date())

        return status
    }
    
    // use cancelDelivery with .none to get status as well as to validate & advance the nonce
    @discardableResult
    public func cancelNone(beepMessage: MessageBlock? = nil) throws -> StatusResponse {
        var statusResponse: StatusResponse

        let cancelResult = cancelDelivery(deliveryType: .none, beepType: .noBeep, beepMessage: beepMessage)
        switch cancelResult {
        case .certainFailure(let error):
            throw error
        case .uncertainFailure(let error):
            throw error
        case .success(let response, _):
            statusResponse = response
        }
        podState.updateFromStatusResponse(statusResponse)
        return statusResponse
    }

    @discardableResult
    public func getStatus(beepMessage: MessageBlock? = nil) throws -> StatusResponse {
        if useCancelNoneForStatus {
            return try cancelNone(beepMessage: beepMessage) // functional replacement for getStatus(), but validates the nonce
        }
        let statusResponse: StatusResponse = try send([GetStatusCommand()], appendMessage: beepMessage)
        podState.updateFromStatusResponse(statusResponse)
        return statusResponse
    }

    public func finalizeFinishedDoses() {
        podState.finalizeFinishedDoses()
    }

    @discardableResult
    public func readPodInfo(podInfoResponseSubType: PodInfoResponseSubType, beepMessage: MessageBlock? = nil) throws -> PodInfoResponse {
        let podInfoCommand = GetStatusCommand(podInfoType: podInfoResponseSubType)
        let podInfoResponseMessageBlock: PodInfoResponse = try send([podInfoCommand], appendMessage: beepMessage)
        return podInfoResponseMessageBlock
    }

    public func deactivatePod() throws {

        // Don't try to cancel if the pod hasn't completed its setup as it will either receive no response
        // (pod progress state <= 2) or a create a $31 pod fault (pod progress states 3 through 7).
        if podState.setupProgress == .completed && podState.fault == nil && !podState.isSuspended {
            let result = cancelDelivery(deliveryType: .all, beepType: .noBeep)
            switch result {
            case .certainFailure(let error):
                throw error
            case .uncertainFailure(let error):
                throw error
            default:
                break
            }
        }

        if let fault = podState.fault {
            // Be sure to clean up the dosing info in case cancelDelivery() wasn't called
            // (or if it was called and it had a fault return) & then read the pulse log.
            handleCancelDosing(deliveryType: .all, bolusNotDelivered: fault.bolusNotDelivered)
            do {
                // read the most recent pulse log entries for later analysis, but don't throw on error
                let podInfoCommand = GetStatusCommand(podInfoType: .pulseLogRecent)
                let _: PodInfoResponse = try send([podInfoCommand])
            } catch let error {
                log.error("Read pulse log failed: %@", String(describing: error))
            }
        }

        do {
            let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)
            let _: StatusResponse = try send([deactivatePod])
        } catch let error as PodCommsError {
            switch error {
            case .podFault, .activationTimeExceeded, .unexpectedResponse:
                break
            default:
                throw error
            }
        }
    }
    
    public func acknowledgeAlerts(alerts: AlertSet, beepMessage: MessageBlock? = nil) throws -> [AlertSlot: PodAlert] {
        let cmd = AcknowledgeAlertCommand(nonce: podState.currentNonce, alerts: alerts)
        let status: StatusResponse = try send([cmd], appendMessage: beepMessage)
        podState.updateFromStatusResponse(status)
        return podState.activeAlerts
    }

    func dosesForStorage(_ storageHandler: ([UnfinalizedDose]) -> Bool) {
        assertOnSessionQueue()

        let dosesToStore = podState.dosesToStore

        if storageHandler(dosesToStore) {
            log.info("Stored doses: %@", String(describing: dosesToStore))
            self.podState.finalizedDoses.removeAll()
        }
    }

    public func assertOnSessionQueue() {
        transport.assertOnSessionQueue()
    }

    public func setPodLowReserviorAlert(level: Double, beepMessage: MessageBlock? = nil) throws {
        // could possible verifying that the new level is above the current reservior value
        log.default("Setting pod alert for low reservior level %s units", String(describing: level))
        guard level > 0 && level <= Pod.maximumReservoirReading else {
            throw PodCommsError.invalidData
        }
        let lowReservoirAlarm = PodAlert.lowReservoirAlarm(level)
        try configureAlerts([lowReservoirAlarm], beepMessage: beepMessage)
    }

    public func setPodExpirationAlert(expirationReminderDate: Date?, beepMessage: MessageBlock? = nil) throws {
        guard let expiryAlert = expirationReminderDate else {
            return
        }
        let timeUntilExpirationAlert = expiryAlert.timeIntervalSinceNow
        guard timeUntilExpirationAlert > 0 else {
            log.default("Pod expiration reminder alert for %s already past %s ago, ignoring", String(describing: expiryAlert), TimeInterval(seconds: -timeUntilExpirationAlert).stringValue)
            return // past the expiration reminder alert time
        }
        log.default("Setting pod expiration reminder alert for %s in %s", String(describing: expiryAlert), TimeInterval(seconds: timeUntilExpirationAlert).stringValue)
        let expirationAlert = PodAlert.expirationAlert(timeUntilExpirationAlert)
        try configureAlerts([expirationAlert], beepMessage: beepMessage)
    }

    public func clearOptionalPodAlarms(beepMessage: MessageBlock? = nil) throws {
        let lowReservoirAlarm = PodAlert.lowReservoirAlarm(0)
        let expirationAlert = PodAlert.expirationAlert(TimeInterval(hours: 0))
        try configureAlerts([lowReservoirAlarm, expirationAlert], beepMessage: beepMessage)
    }
}

extension PodCommsSession: MessageTransportDelegate {
    func messageTransport(_ messageTransport: MessageTransport, didUpdate state: MessageTransportState) {
        messageTransport.assertOnSessionQueue()
        podState.messageTransportState = state
    }
}
