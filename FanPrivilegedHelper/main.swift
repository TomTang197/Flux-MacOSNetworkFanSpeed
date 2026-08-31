//
//  main.swift
//  FanPrivilegedHelper
//
//  Created by Bandan.K on 03/02/26.
//  Updated with complete SMC control & reset engine on 30/08/26.
//

import Foundation
import Darwin
import IOKit
import os.log
import Security

// MARK: - XPC Protocol (helper side)

@objc protocol FanHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func heartbeat(withReply reply: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
    func setFanTargets(indices: [NSNumber], rpms: [NSNumber], withReply reply: @escaping (Int32) -> Void)
    func resetToAutomatic(withReply reply: @escaping (Int32) -> Void)
}

// MARK: - SMC Low-Level Implementation (write-focused)

final class SMCWriter {
    private var connection: io_connect_t = 0
    private let logger = Logger(
        subsystem: "com.bandan.me.AeroPulse.FanService",
        category: "SMCWriter"
    )
    private var openedConnectionType: UInt32?
    private var isFanModeKeyLower: Bool? = nil
    private var cachedFanCount: Int?

    init?() {
        guard open() else { return nil }
    }

    deinit {
        close()
    }

    private func open() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            logger.error("AppleSMC service not found")
            return false
        }
        defer { IOObjectRelease(service) }

        // Type 2 is write-capable, fall back to 1 and 0 for broader hardware compatibility.
        var result: kern_return_t = kIOReturnError
        for type in [UInt32(2), 1, 0] {
            result = IOServiceOpen(service, mach_task_self_, type, &connection)
            if result == kIOReturnSuccess, connection != 0 {
                openedConnectionType = type
                logger.notice("Opened AppleSMC with connection type \(type)")
                break
            }
        }

        guard result == kIOReturnSuccess, connection != 0 else {
            logger.error("Failed to open AppleSMC connection: \(result)")
            return false
        }

        return true
    }

    private func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    struct SMCParamStruct {
        var key: UInt32 = 0
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
        var plLimitVersion: UInt16 = 0
        var plLimitLength: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        var res1: UInt8 = 0
        var res2: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var res3: UInt8 = 0
        var data32: UInt32 = 0
        var bytes:
            (
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
            ) = (
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            )
        init() {}
    }

    private enum SMCSelector: UInt32 {
        case callMethod = 2
    }

    private enum SMCCmd: UInt8 {
        case readValue = 5
        case writeValue = 6
        case readInfo = 9
    }

    private func stringToKey(_ name: String) -> UInt32 {
        var key: UInt32 = 0
        for char in name.utf8.prefix(4) {
            key = (key << 8) | UInt32(char)
        }
        return key
    }

    private func callSMC(_ cmd: SMCCmd, inputStruct: inout SMCParamStruct) -> kern_return_t {
        guard connection != 0 else { return kIOReturnNotOpen }

        let inputStructSize = MemoryLayout<SMCParamStruct>.size
        var outputStruct = SMCParamStruct()
        var outputStructSize = MemoryLayout<SMCParamStruct>.size

        inputStruct.data8 = cmd.rawValue

        let result = IOConnectCallStructMethod(
            connection,
            SMCSelector.callMethod.rawValue,
            &inputStruct,
            inputStructSize,
            &outputStruct,
            &outputStructSize
        )

        if result == kIOReturnSuccess {
            inputStruct = outputStruct
        }

        return result
    }

    private func getInfo(_ name: String) -> (size: UInt32, type: UInt32)? {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)

        let res = callSMC(.readInfo, inputStruct: &inputStruct)
        guard res == kIOReturnSuccess, inputStruct.result == 0, inputStruct.dataSize > 0 else { return nil }
        return (inputStruct.dataSize, inputStruct.dataType)
    }

    private func readNumericKey(_ name: String) -> Int? {
        guard let info = getInfo(name) else { return nil }

        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = info.size
        guard callSMC(.readValue, inputStruct: &inputStruct) == kIOReturnSuccess,
              inputStruct.result == 0 else {
            return nil
        }

        let bytes = withUnsafeBytes(of: inputStruct.bytes) { Array($0) }
        let type = info.type

        if type == stringToKey("flt "), bytes.count >= 4 {
            var value: Float = 0
            withUnsafeMutableBytes(of: &value) { destination in
                destination.copyBytes(from: bytes.prefix(4))
            }
            guard value.isFinite else { return nil }
            return Int(value.rounded())
        }

        if type == stringToKey("fpe2"), bytes.count >= 2 {
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Int(raw) / 4
        }

        if type == stringToKey("ui8 "), !bytes.isEmpty {
            return Int(bytes[0])
        }

        if type == stringToKey("ui16"), bytes.count >= 2 {
            return Int(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        }

        if type == stringToKey("ui32"), bytes.count >= 4 {
            let raw = UInt32(bytes[0]) << 24
                | UInt32(bytes[1]) << 16
                | UInt32(bytes[2]) << 8
                | UInt32(bytes[3])
            return Int(raw)
        }

        if info.size == 1, !bytes.isEmpty {
            return Int(bytes[0])
        }
        if info.size == 2, bytes.count >= 2 {
            return Int(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        }
        return nil
    }

    private func detectedFanCount() -> Int? {
        if let cachedFanCount { return cachedFanCount }

        for key in ["FNum", "Num ", "#pn "] {
            if let count = readNumericKey(key), count > 0, count <= 16 {
                cachedFanCount = count
                return count
            }
        }
        return nil
    }

    private func fanRPMBounds(index: Int) -> (minimum: Int?, maximum: Int?) {
        (
            minimum: readNumericKey("F\(index)Mn"),
            maximum: readNumericKey("F\(index)Mx")
        )
    }

    private func writeKeyRaw(_ name: String, dataType: UInt32, bytes: [UInt8]) -> kern_return_t {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = UInt32(bytes.count)
        inputStruct.dataType = dataType
        inputStruct.dataAttributes = 0x80

        withUnsafeMutableBytes(of: &inputStruct.bytes) { ptr in
            for (i, byte) in bytes.enumerated() where i < 32 {
                ptr[i] = byte
            }
        }

        // Retry loop: retry up to 10 times with 50ms interval (identical to iFan)
        var lastRes: kern_return_t = kIOReturnError
        for _ in 0..<10 {
            lastRes = callSMC(.writeValue, inputStruct: &inputStruct)
            if lastRes == kIOReturnSuccess && inputStruct.result == 0 {
                return kIOReturnSuccess
            }
            usleep(50000)
        }

        logger.error(
            "SMC write failed key=\(name, privacy: .public) smcResult=\(inputStruct.result) status=\(inputStruct.status) dataType=\(inputStruct.dataType) dataSize=\(inputStruct.dataSize)"
        )
        return lastRes == kIOReturnSuccess ? (inputStruct.result == 0 ? kIOReturnSuccess : kIOReturnError) : lastRes
    }

    private func resolveFanModeKey(index: Int) -> String {
        if let isLower = isFanModeKeyLower {
            return isLower ? "F\(index)md" : "F\(index)Md"
        }
        if getInfo("F0md") != nil {
            isFanModeKeyLower = true
            return "F\(index)md"
        } else {
            isFanModeKeyLower = false
            return "F\(index)Md"
        }
    }

    // MARK: - SMC Tool Runner with Direct IOKit Fallback

    private func runSMCTool(args: [String]) -> Bool {
        let candidates = [
            "/Library/PrivilegedHelperTools/SMC",
            "/Applications/iFan.app/Contents/Resources/SMC",
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("SMC").path,
            Bundle.main.resourceURL?.appendingPathComponent("SMC").path ?? "",
        ]

        guard let executablePath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = args
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
            guard completion.wait(timeout: .now() + 3) == .success else {
                logger.error("SMC tool timed out; terminating it")
                process.terminate()
                if completion.wait(timeout: .now() + 1) == .timedOut, process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                    _ = completion.wait(timeout: .now() + 1)
                }
                return false
            }
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Public fan control methods

    func setFanMode(index: Int, manual: Bool) -> kern_return_t {
        guard FanCommandValidator.isValidFanIndex(index, fanCount: detectedFanCount()) else {
            logger.error("Rejected invalid fan index \(index)")
            return kIOReturnBadArgument
        }

        return PrimaryFallbackExecutor.run(
            primary: { self.setFanModeDirect(index: index, manual: manual) },
            isSuccess: { $0 == kIOReturnSuccess },
            fallback: {
                self.runSMCTool(args: ["fan", "\(index)", "-m", manual ? "1" : "0"])
                    ? kIOReturnSuccess : kIOReturnError
            }
        )
    }

    private func setFanModeDirect(
        index: Int,
        manual: Bool,
        enableFtst: Bool = true
    ) -> kern_return_t {
        let modeKey = resolveFanModeKey(index: index)
        let ui8Type = stringToKey("ui8 ")
        let ftstInfo = getInfo("Ftst")
        let modeInfo = getInfo(modeKey)
        var modeRes: kern_return_t = kIOReturnError

        for operation in FanModeWritePlanner.plan(
            manual: manual,
            hasFtst: enableFtst && ftstInfo != nil
        ) {
            var result: kern_return_t = kIOReturnSuccess
            switch operation {
            case .writeFtst(let value):
                guard let ftstInfo else { return kIOReturnNotFound }
                result = writeKeyRaw(
                    "Ftst",
                    dataType: ftstInfo.type != 0 ? ftstInfo.type : ui8Type,
                    bytes: [value]
                )
            case .wait(let seconds):
                if seconds > 0 {
                    Thread.sleep(forTimeInterval: min(seconds, 30))
                }
            case .writeMode(let value):
                result = writeKeyRaw(
                    modeKey,
                    dataType: modeInfo?.type ?? ui8Type,
                    bytes: [value]
                )
                if manual, ftstInfo != nil, result != kIOReturnSuccess {
                    var attempt = 1
                    logger.notice("Fan \(index) mode write rejected; retrying after Ftst unlock")
                    while result != kIOReturnSuccess,
                          FanModeUnlockRetryPolicy.shouldRetry(afterAttempt: attempt) {
                        Thread.sleep(forTimeInterval: FanModeUnlockRetryPolicy.retryInterval)
                        result = writeKeyRaw(
                            modeKey,
                            dataType: modeInfo?.type ?? ui8Type,
                            bytes: [value]
                        )
                        attempt += 1
                    }
                    logger.notice("Fan \(index) mode write retry finished attempts=\(attempt) result=\(result)")
                }
                modeRes = result
            }
            guard result == kIOReturnSuccess else { return result }
        }
        var forceMaskRes: kern_return_t = kIOReturnSuccess

        // On Intel Macs, also update the FS! bitmask
        let forceKey = "FS! "
        if let info = getInfo(forceKey) {
            let mask = UInt16(1 << index)
            var readParam = SMCParamStruct()
            readParam.key = stringToKey(forceKey)
            readParam.dataSize = 2
            guard callSMC(.readValue, inputStruct: &readParam) == kIOReturnSuccess,
                  readParam.result == 0 else {
                logger.error("Refused to update FS! without reading its current mask")
                return modeRes == kIOReturnSuccess ? kIOReturnError : modeRes
            }
            var currentMask = UInt16(readParam.bytes.0) << 8 | UInt16(readParam.bytes.1)
            if manual {
                currentMask |= mask
            } else {
                currentMask &= ~mask
            }
            let ui16Type = info.type != 0 ? info.type : stringToKey("ui16")
            let fsBytes: [UInt8] = [UInt8((currentMask >> 8) & 0xFF), UInt8(currentMask & 0xFF)]
            forceMaskRes = writeKeyRaw(forceKey, dataType: ui16Type, bytes: fsBytes)
        }

        guard modeRes == kIOReturnSuccess else { return modeRes }
        return forceMaskRes
    }

    func setFanTargetRPM(index: Int, rpm: Int) -> kern_return_t {
        let validationResult = validateFanTarget(index: index, rpm: rpm)
        guard validationResult == kIOReturnSuccess else { return validationResult }

        return PrimaryFallbackExecutor.run(
            primary: { self.setFanTargetRPMDirect(index: index, rpm: rpm) },
            isSuccess: { $0 == kIOReturnSuccess },
            fallback: {
                self.runSMCTool(args: ["fan", "\(index)", "-v", "\(rpm)"])
                    ? kIOReturnSuccess : kIOReturnError
            }
        )
    }

    private func setFanTargetRPMDirect(
        index: Int,
        rpm: Int,
        enableFtst: Bool = true
    ) -> kern_return_t {
        // First ensure fan is switched to manual mode
        let modeResult = setFanModeDirect(index: index, manual: true, enableFtst: enableFtst)
        guard modeResult == kIOReturnSuccess else { return modeResult }

        return writeFanTargetRPMDirect(index: index, rpm: rpm)
    }

    private func writeFanTargetRPMDirect(index: Int, rpm: Int) -> kern_return_t {

        let tgKey = "F\(index)Tg"
        guard let info = getInfo(tgKey) else {
            logger.error("Fan target key F\(index)Tg not found")
            return kIOReturnNotFound
        }

        var dataBytes: [UInt8] = []
        let typeFLT = stringToKey("flt ")

        if info.type == typeFLT || (info.type == 0 && info.size >= 4) {
            // Apple Silicon (M1/M2/M3/M4): IEEE 754 Float32 little-endian
            var floatRPM = Float(max(rpm, 0))
            withUnsafeBytes(of: &floatRPM) { src in
                dataBytes = Array(src)
            }
        } else {
            // Intel: 14.2 fixed-point (RPM * 4) big-endian
            let clamped = UInt16(min(max(rpm, 0), 16383)) << 2
            dataBytes = [UInt8((clamped >> 8) & 0xFF), UInt8(clamped & 0xFF)]
        }

        return writeKeyRaw(tgKey, dataType: info.type, bytes: dataBytes)
    }

    func setFanTargets(targets: [(index: Int, rpm: Int)]) -> kern_return_t {
        guard !targets.isEmpty, targets.count <= 16 else {
            return kIOReturnBadArgument
        }
        for target in targets {
            let validationResult = validateFanTarget(index: target.index, rpm: target.rpm)
            guard validationResult == kIOReturnSuccess else { return validationResult }
        }

        return PrimaryFallbackExecutor.run(
            primary: { self.setFanTargetsDirect(targets: targets) },
            isSuccess: { $0 == kIOReturnSuccess },
            fallback: {
                for target in targets {
                    guard self.runSMCTool(args: ["fan", "\(target.index)", "-v", "\(target.rpm)"]) else {
                        return kIOReturnError
                    }
                }
                return kIOReturnSuccess
            }
        )
    }

    private func setFanTargetsDirect(targets: [(index: Int, rpm: Int)]) -> kern_return_t {
        let hasFtst = getInfo("Ftst") != nil
        logger.notice("Starting direct fan-target batch count=\(targets.count) hasFtst=\(hasFtst)")
        for operation in FanTargetBatchWritePlanner.plan(targets: targets, hasFtst: hasFtst) {
            switch operation {
            case .writeFtst(let value):
                guard let ftstInfo = getInfo("Ftst") else { return kIOReturnNotFound }
                let result = writeKeyRaw(
                    "Ftst",
                    dataType: ftstInfo.type != 0 ? ftstInfo.type : stringToKey("ui8 "),
                    bytes: [value]
                )
                logger.notice("Direct batch Ftst write value=\(value) result=\(result)")
                guard result == kIOReturnSuccess else { return result }

            case .wait(let seconds):
                if seconds > 0 {
                    logger.notice("Waiting \(seconds, privacy: .public)s after Ftst unlock")
                    Thread.sleep(forTimeInterval: min(seconds, 30))
                }

            case .writeMode(let index, let value):
                let result = setFanModeDirect(
                    index: index,
                    manual: value != 0,
                    enableFtst: false
                )
                logger.notice("Direct batch mode write fan=\(index) value=\(value) result=\(result)")
                guard result == kIOReturnSuccess else { return result }

            case .writeTarget(let index, let rpm):
                let result = writeFanTargetRPMDirect(index: index, rpm: rpm)
                logger.notice("Direct batch target write fan=\(index) rpm=\(rpm) result=\(result)")
                guard result == kIOReturnSuccess else { return result }
            }
        }
        logger.notice("Direct fan-target batch completed successfully")
        return kIOReturnSuccess
    }

    func validateFanTarget(index: Int, rpm: Int) -> kern_return_t {
        guard FanCommandValidator.isValidFanIndex(index, fanCount: detectedFanCount()) else {
            logger.error("Rejected invalid fan index \(index)")
            return kIOReturnBadArgument
        }

        let bounds = fanRPMBounds(index: index)
        guard FanCommandValidator.isValidTargetRPM(
            rpm,
            minimum: bounds.minimum,
            maximum: bounds.maximum
        ) else {
            logger.error(
                "Rejected invalid target RPM \(rpm) for fan \(index), min=\(bounds.minimum ?? -1), max=\(bounds.maximum ?? -1)"
            )
            return kIOReturnBadArgument
        }
        return kIOReturnSuccess
    }

    func resetToAutomatic() -> kern_return_t {
        if runSMCTool(args: ["reset"]) {
            return kIOReturnSuccess
        }

        // Apple Silicon: write 0 to Ftst to exit test/manual override
        if getInfo("Ftst") != nil {
            let res = writeKeyRaw("Ftst", dataType: stringToKey("ui8 "), bytes: [0])
            if res == kIOReturnSuccess {
                return kIOReturnSuccess
            }
        }

        // Fallback: iterate over all fans and restore automatic mode
        let fanCount = detectedFanCount() ?? 2

        var firstFailure: kern_return_t?
        for i in 0..<fanCount {
            let result = setFanMode(index: i, manual: false)
            if result != kIOReturnSuccess, firstFailure == nil {
                firstFailure = result
            }
        }
        return firstFailure ?? kIOReturnSuccess
    }
}

// MARK: - Fan control lease service

final class FanControlService {
    private let smcWriter = SMCWriter()
    private let logger = Logger(subsystem: "com.bandan.me.AeroPulse.FanService", category: "FanControlService")
    private let controlQueue = DispatchQueue(label: "com.bandan.me.AeroPulse.FanService.control")
    private var lease = FanControlLease(timeout: 12)
    private var watchdog: DispatchSourceTimer?

    init() {
        startWatchdog()
    }

    deinit {
        watchdog?.cancel()
    }

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: controlQueue)
        timer.schedule(deadline: .now() + 2, repeating: 2, leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            self?.restoreIfLeaseExpired()
        }
        watchdog = timer
        timer.resume()
    }

    private func restoreIfLeaseExpired() {
        guard lease.shouldRestore(at: Date()) else { return }
        _ = restoreAutomatic(reason: "heartbeat timeout", force: false)
    }

    @discardableResult
    private func restoreAutomatic(reason: String, force: Bool) -> kern_return_t {
        guard force || lease.isActive else { return kIOReturnSuccess }
        guard let writer = smcWriter else {
            logger.error("Automatic restore failed (\(reason, privacy: .public)): smcWriter is nil")
            return kIOReturnNotOpen
        }

        let result = writer.resetToAutomatic()
        if result == kIOReturnSuccess {
            lease.noteRestoredAll()
            logger.notice("Restored automatic fan control: \(reason, privacy: .public)")
        } else {
            lease.noteRecoveryRequired()
            logger.error("Automatic restore failed (\(reason, privacy: .public)): \(result)")
        }
        return result
    }

    private func recoverAfterFailedWrite(reason: String) {
        lease.noteRecoveryRequired()
        let result = restoreAutomatic(reason: reason, force: false)
        if result != kIOReturnSuccess {
            logger.fault("Failed write could not be rolled back; watchdog will retry: \(result)")
        }
    }

    func clientDisconnected(_ clientID: UUID) {
        controlQueue.async { [weak self] in
            guard let self, self.lease.shouldRestoreAfterDisconnect(of: clientID) else { return }
            _ = self.restoreAutomatic(reason: "owning XPC client disconnected", force: false)
        }
    }

    func ping(withReply reply: @escaping (Bool) -> Void) {
        controlQueue.async { [weak self] in
            guard let self else {
                reply(false)
                return
            }
            self.logger.notice("Received ping")
            reply(self.smcWriter != nil)
        }
    }

    func heartbeat(clientID: UUID, withReply reply: @escaping (Bool) -> Void) {
        controlQueue.async { [weak self] in
            guard let self else {
                reply(false)
                return
            }
            reply(self.lease.noteHeartbeat(owner: clientID, at: Date()))
        }
    }

    func setFanMode(clientID: UUID, index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void) {
        controlQueue.async { [weak self] in
            guard let self, let writer = self.smcWriter else {
                reply(kIOReturnNotOpen)
                return
            }
            guard self.lease.allowsControl(from: clientID) else {
                self.logger.error("Rejected fan mode request from non-owning XPC client")
                reply(kIOReturnExclusiveAccess)
                return
            }

            if manual {
                // Track recovery responsibility before writing because an external tool may
                // partially apply a command even when it eventually reports failure.
                _ = self.lease.noteControl(ofFan: index, owner: clientID, at: Date())
            }
            let result = writer.setFanMode(index: index, manual: manual)
            if result == kIOReturnSuccess {
                if !manual { self.lease.noteRestored(fan: index, owner: clientID) }
            } else if manual {
                self.recoverAfterFailedWrite(reason: "failed manual-mode write")
            }
            self.logger.notice("setFanMode(index: \(index), manual: \(manual)) -> \(result)")
            reply(result)
        }
    }

    func setFanTargetRPM(clientID: UUID, index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void) {
        controlQueue.async { [weak self] in
            guard let self, let writer = self.smcWriter else {
                reply(kIOReturnNotOpen)
                return
            }
            guard self.lease.allowsControl(from: clientID) else {
                self.logger.error("Rejected target RPM request from non-owning XPC client")
                reply(kIOReturnExclusiveAccess)
                return
            }

            _ = self.lease.noteControl(ofFan: index, owner: clientID, at: Date())
            let result = writer.setFanTargetRPM(index: index, rpm: rpm)
            if result != kIOReturnSuccess {
                self.recoverAfterFailedWrite(reason: "failed target-RPM write")
            }
            self.logger.notice("setFanTargetRPM(index: \(index), rpm: \(rpm)) -> \(result)")
            reply(result)
        }
    }

    func setFanTargets(
        clientID: UUID,
        indices: [NSNumber],
        rpms: [NSNumber],
        withReply reply: @escaping (Int32) -> Void
    ) {
        controlQueue.async { [weak self] in
            guard let self, let writer = self.smcWriter else {
                reply(kIOReturnNotOpen)
                return
            }
            guard !indices.isEmpty, indices.count == rpms.count, indices.count <= 16 else {
                reply(kIOReturnBadArgument)
                return
            }
            guard self.lease.allowsControl(from: clientID) else {
                reply(kIOReturnExclusiveAccess)
                return
            }

            let targets = zip(indices, rpms).map {
                (index: $0.0.intValue, rpm: $0.1.intValue)
            }
            for target in targets {
                let result = writer.validateFanTarget(index: target.index, rpm: target.rpm)
                guard result == kIOReturnSuccess else {
                    reply(result)
                    return
                }
            }

            let now = Date()
            for target in targets {
                _ = self.lease.noteControl(ofFan: target.index, owner: clientID, at: now)
            }
            let result = writer.setFanTargets(targets: targets)
            if result != kIOReturnSuccess {
                self.recoverAfterFailedWrite(reason: "failed atomic fan-target batch")
                reply(result)
                return
            }
            _ = self.lease.noteProgress(owner: clientID, at: Date())
            reply(kIOReturnSuccess)
        }
    }

    func resetToAutomatic(clientID: UUID, withReply reply: @escaping (Int32) -> Void) {
        controlQueue.async { [weak self] in
            guard let self else {
                reply(kIOReturnNotOpen)
                return
            }
            guard self.lease.allowsRecovery(from: clientID) else {
                self.logger.error("Rejected reset request from non-owning XPC client")
                reply(kIOReturnExclusiveAccess)
                return
            }
            let result = self.restoreAutomatic(reason: "client request", force: true)
            reply(result)
        }
    }
}

final class FanHelperConnection: NSObject, FanHelperProtocol {
    private let clientID = UUID()
    private let service: FanControlService

    init(service: FanControlService) {
        self.service = service
        super.init()
    }

    func clientDisconnected() {
        service.clientDisconnected(clientID)
    }

    func ping(withReply reply: @escaping (Bool) -> Void) {
        service.ping(withReply: reply)
    }

    func heartbeat(withReply reply: @escaping (Bool) -> Void) {
        service.heartbeat(clientID: clientID, withReply: reply)
    }

    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void) {
        service.setFanMode(clientID: clientID, index: index, manual: manual, withReply: reply)
    }

    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void) {
        service.setFanTargetRPM(clientID: clientID, index: index, rpm: rpm, withReply: reply)
    }

    func setFanTargets(indices: [NSNumber], rpms: [NSNumber], withReply reply: @escaping (Int32) -> Void) {
        service.setFanTargets(clientID: clientID, indices: indices, rpms: rpms, withReply: reply)
    }

    func resetToAutomatic(withReply reply: @escaping (Int32) -> Void) {
        service.resetToAutomatic(clientID: clientID, withReply: reply)
    }
}

// MARK: - XPC Service Delegate

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service = FanControlService()
    private let logger = Logger(
        subsystem: "com.bandan.me.AeroPulse.FanService",
        category: "XPC"
    )
    private lazy var exportedInterface: NSXPCInterface = {
        NSXPCInterface(with: FanHelperProtocol.self)
    }()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard isConnectionAllowed(connection) else {
            logger.error(
                "Rejected XPC client pid=\(connection.processIdentifier, privacy: .public) uid=\(connection.effectiveUserIdentifier, privacy: .public)"
            )
            return false
        }

        let helper = FanHelperConnection(service: service)
        connection.exportedInterface = exportedInterface
        connection.exportedObject = helper
        connection.interruptionHandler = { [weak helper] in
            helper?.clientDisconnected()
        }
        connection.invalidationHandler = { [weak helper] in
            helper?.clientDisconnected()
        }
        connection.resume()
        logger.notice("Accepted XPC client pid=\(connection.processIdentifier, privacy: .public)")
        return true
    }

    private func isConnectionAllowed(_ connection: NSXPCConnection) -> Bool {
        connection.processIdentifier > 0
    }
}

// MARK: - Entry point

let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: "com.bandan.me.AeroPulse.FanService")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
