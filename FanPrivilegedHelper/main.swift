//
//  main.swift
//  FanPrivilegedHelper
//
//  Created by Bandan.K on 03/02/26.
//  Updated with complete SMC control & reset engine on 30/08/26.
//

import Foundation
import IOKit
import os.log
import Security

// MARK: - XPC Protocol (helper side)

@objc protocol FanHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
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

        logger.debug(
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

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Public fan control methods

    func setFanMode(index: Int, manual: Bool) -> kern_return_t {
        if runSMCTool(args: ["fan", "\(index)", "-m", manual ? "1" : "0"]) {
            return kIOReturnSuccess
        }

        let modeKey = resolveFanModeKey(index: index)
        let modeVal: UInt8 = manual ? 1 : 0
        let ui8Type = stringToKey("ui8 ")
        let modeRes = writeKeyRaw(modeKey, dataType: ui8Type, bytes: [modeVal])

        // On Intel Macs, also update the FS! bitmask
        let forceKey = "FS! "
        if let info = getInfo(forceKey) {
            let mask = UInt16(1 << index)
            var currentMask: UInt16 = 0
            var readParam = SMCParamStruct()
            readParam.key = stringToKey(forceKey)
            readParam.dataSize = 2
            if callSMC(.readValue, inputStruct: &readParam) == kIOReturnSuccess && readParam.result == 0 {
                currentMask = UInt16(readParam.bytes.0) << 8 | UInt16(readParam.bytes.1)
            }
            if manual {
                currentMask |= mask
            } else {
                currentMask &= ~mask
            }
            let ui16Type = info.type != 0 ? info.type : stringToKey("ui16")
            let fsBytes: [UInt8] = [UInt8((currentMask >> 8) & 0xFF), UInt8(currentMask & 0xFF)]
            _ = writeKeyRaw(forceKey, dataType: ui16Type, bytes: fsBytes)
        }

        return modeRes
    }

    func setFanTargetRPM(index: Int, rpm: Int) -> kern_return_t {
        if runSMCTool(args: ["fan", "\(index)", "-v", "\(rpm)"]) {
            return kIOReturnSuccess
        }

        // First ensure fan is switched to manual mode
        _ = setFanMode(index: index, manual: true)

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
        var fanCount = 2
        var fnumParam = SMCParamStruct()
        fnumParam.key = stringToKey("FNum")
        fnumParam.dataSize = 1
        if callSMC(.readValue, inputStruct: &fnumParam) == kIOReturnSuccess && fnumParam.result == 0 {
            fanCount = max(Int(fnumParam.bytes.0), 1)
        }

        for i in 0..<fanCount {
            _ = setFanMode(index: i, manual: false)
        }
        return kIOReturnSuccess
    }
}

// MARK: - XPC Service Delegate

final class FanHelper: NSObject, FanHelperProtocol {
    private let smcWriter = SMCWriter()
    private let logger = Logger(subsystem: "com.bandan.me.AeroPulse.FanService", category: "FanHelper")

    func ping(withReply reply: @escaping (Bool) -> Void) {
        logger.notice("Received ping")
        reply(smcWriter != nil)
    }

    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void) {
        guard let writer = smcWriter else {
            logger.error("setFanMode failed: smcWriter is nil")
            reply(kIOReturnNotOpen)
            return
        }
        let result = writer.setFanMode(index: index, manual: manual)
        logger.notice("setFanMode(index: \(index), manual: \(manual)) -> \(result)")
        reply(result)
    }

    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void) {
        guard let writer = smcWriter else {
            logger.error("setFanTargetRPM failed: smcWriter is nil")
            reply(kIOReturnNotOpen)
            return
        }
        let result = writer.setFanTargetRPM(index: index, rpm: rpm)
        logger.notice("setFanTargetRPM(index: \(index), rpm: \(rpm)) -> \(result)")
        reply(result)
    }

    func resetToAutomatic(withReply reply: @escaping (Int32) -> Void) {
        guard let writer = smcWriter else {
            logger.error("resetToAutomatic failed: smcWriter is nil")
            reply(kIOReturnNotOpen)
            return
        }
        let result = writer.resetToAutomatic()
        logger.notice("resetToAutomatic() -> \(result)")
        reply(result)
    }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let exportedObject = FanHelper()
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

        connection.exportedInterface = exportedInterface
        connection.exportedObject = exportedObject
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


