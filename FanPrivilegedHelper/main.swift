//
//  main.swift
//  FanPrivilegedHelper
//
//  Created by Bandan.K on 03/02/26.
//

import Foundation
import IOKit
import Security
import os.log

// MARK: - XPC Protocol (helper side)

@objc protocol FanHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
}

// MARK: - SMC Low-Level Implementation (write-focused)

final class SMCWriter {
    private var connection: io_connect_t = 0
    private let logger = Logger(
        subsystem: "com.bandan.me.MacOSNetworkFanSpeed.FanService",
        category: "SMCWriter"
    )
    private var openedConnectionType: UInt32?
    private var hasLoggedMissingModeKeys = false

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

        // Prefer write-capable type 2, but keep fallbacks for models where type 1/0 works.
        var result: kern_return_t = kIOReturnError
        for type in [UInt32(2), 1, 0] {
            result = IOServiceOpen(service, mach_task_self_, type, &connection)
            if result == kIOReturnSuccess, connection != 0 {
                openedConnectionType = type
                logger.notice("Opened AppleSMC with connection type \(type)")
                break
            } else {
                logger.debug("IOServiceOpen type \(type) failed: \(result)")
            }
        }
        IOObjectRelease(service)

        guard result == kIOReturnSuccess, connection != 0 else {
            logger.error("Failed to open AppleSMC connection: \(result)")
            return false
        }

        unlockDiagnosticsIfAvailable()
        return true
    }

    private func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    struct SMCVal {
        var key: UInt32 = 0
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var bytes: [UInt8] = Array(repeating: 0, count: 32)
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
    }

    enum SMCSelector: UInt32 {
        case callMethod = 2
    }

    enum SMCCmd: UInt8 {
        case readValue = 5
        case writeValue = 6
        case readInfo = 9
    }

    private func stringToKey(_ name: String) -> UInt32 {
        var key: UInt32 = 0
        for char in name.utf8 {
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
        guard res == kIOReturnSuccess, inputStruct.result == 0 else { return nil }
        return (inputStruct.dataSize, inputStruct.dataType)
    }

    private func readKey(_ name: String, dataSize: UInt32) -> SMCVal? {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = dataSize

        let res = callSMC(.readValue, inputStruct: &inputStruct)
        guard res == kIOReturnSuccess, inputStruct.result == 0 else { return nil }

        var val = SMCVal()
        val.key = inputStruct.key
        val.dataSize = inputStruct.dataSize
        val.dataType = inputStruct.dataType
        val.bytes = withUnsafeBytes(of: inputStruct.bytes) { Array($0) }
        return val
    }

    private func mapSMCResultToIOReturn(_ smcResult: UInt8) -> kern_return_t {
        switch smcResult {
        case 0:
            return kIOReturnSuccess
        case 132:
            return kIOReturnNotFound
        default:
            return kIOReturnError
        }
    }

    private func writeKey(_ name: String, val: SMCVal) -> kern_return_t {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = val.dataSize
        inputStruct.dataType = val.dataType
        inputStruct.dataAttributes = 0x80

        for (i, byte) in val.bytes.enumerated() {
            if i >= 32 { break }
            withUnsafeMutablePointer(to: &inputStruct.bytes) { pointer in
                let bPointer = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
                bPointer[i] = byte
            }
        }

        let res = callSMC(.writeValue, inputStruct: &inputStruct)
        guard res == kIOReturnSuccess else { return res }
        if inputStruct.result == 0 { return kIOReturnSuccess }

        logger.debug(
            "SMC write rejected key=\(name, privacy: .public) smcResult=\(inputStruct.result) status=\(inputStruct.status) dataType=\(inputStruct.dataType) dataSize=\(inputStruct.dataSize) openType=\(self.openedConnectionType ?? 999)"
        )
        return mapSMCResultToIOReturn(inputStruct.result)
    }

    private func unlockDiagnosticsIfAvailable() {
        guard let info = getInfo("Ftst") else { return }

        var val = SMCVal()
        val.dataSize = max(info.size, 1)
        val.dataType = info.type
        val.bytes[0] = 1
        _ = writeKey("Ftst", val: val)
    }

    private func writeRPMBytes(to val: inout SMCVal, rpm: Int) {
        let clampedRPM = max(rpm, 0)
        let typeFPE2 = stringToKey("fpe2")
        let typeFLT = stringToKey("flt ")
        let typeUI16 = stringToKey("ui16")
        let typeUI32 = stringToKey("ui32")

        if val.dataType == typeFLT || (val.dataType == 0 && val.dataSize >= 4) {
            var floatRPM = Float(clampedRPM)
            withUnsafeBytes(of: &floatRPM) { src in
                let count = min(Int(val.dataSize), src.count)
                for idx in 0..<count {
                    val.bytes[idx] = src[idx]
                }
            }
            return
        }

        if val.dataType == typeUI32 {
            let encoded = UInt32(clampedRPM)
            val.bytes[0] = UInt8((encoded >> 24) & 0xFF)
            val.bytes[1] = UInt8((encoded >> 16) & 0xFF)
            val.bytes[2] = UInt8((encoded >> 8) & 0xFF)
            val.bytes[3] = UInt8(encoded & 0xFF)
            return
        }

        if val.dataType == typeUI16 {
            let encoded = UInt16(min(clampedRPM, Int(UInt16.max)))
            val.bytes[0] = UInt8((encoded >> 8) & 0xFF)
            val.bytes[1] = UInt8(encoded & 0xFF)
            return
        }

        if val.dataType == typeFPE2 || val.dataSize <= 2 {
            let encoded = UInt16(min(clampedRPM, Int(UInt16.max >> 2))) << 2
            val.bytes[0] = UInt8((encoded >> 8) & 0xFF)
            val.bytes[1] = UInt8(encoded & 0xFF)
            return
        }

        var floatRPM = Float(clampedRPM)
        withUnsafeBytes(of: &floatRPM) { src in
            let count = min(Int(val.dataSize), src.count)
            for idx in 0..<count {
                val.bytes[idx] = src[idx]
            }
        }
    }

    // MARK: - Public fan helpers

    func setFanMode(index: Int, manual: Bool) -> kern_return_t {
        let modeKey = "F\(index)Md"
        let forceKey = "FS! "
        var hadModeControlKey = false
        var lastFailure: kern_return_t = kIOReturnSuccess

        if let info = getInfo(modeKey) {
            hadModeControlKey = true

            var modeVal = SMCVal()
            modeVal.dataSize = max(info.size, 1)
            modeVal.dataType = info.type == 0 ? stringToKey("ui8 ") : info.type
            modeVal.bytes[0] = manual ? 1 : 0

            let modeRes = writeKey(modeKey, val: modeVal)
            if modeRes != kIOReturnSuccess && modeRes != kIOReturnNotFound {
                return modeRes
            }
            lastFailure = modeRes
        } else {
            // Some models do not expose key info but still accept direct mode writes.
            var modeVal = SMCVal()
            modeVal.dataSize = 1
            modeVal.dataType = stringToKey("ui8 ")
            modeVal.bytes[0] = manual ? 1 : 0

            let modeRes = writeKey(modeKey, val: modeVal)
            if modeRes == kIOReturnSuccess {
                hadModeControlKey = true
                lastFailure = kIOReturnSuccess
            } else if modeRes != kIOReturnNotFound {
                return modeRes
            }
        }

        if let info = getInfo(forceKey) {
            hadModeControlKey = true

            let mask = UInt16(1 << index)
            var currentMask: UInt16 = 0
            if let existing = readKey(forceKey, dataSize: max(info.size, 2)), existing.dataSize >= 2 {
                currentMask = UInt16(existing.bytes[0]) << 8 | UInt16(existing.bytes[1])
            }

            if manual {
                currentMask |= mask
            } else {
                currentMask &= ~mask
            }

            var fsVal = SMCVal()
            fsVal.dataSize = max(info.size, 2)
            fsVal.dataType = info.type == 0 ? stringToKey("ui16") : info.type
            fsVal.bytes[0] = UInt8((currentMask >> 8) & 0xFF)
            fsVal.bytes[1] = UInt8(currentMask & 0xFF)

            let fsRes = writeKey(forceKey, val: fsVal)
            if fsRes != kIOReturnSuccess && fsRes != kIOReturnNotFound {
                return fsRes
            }
            lastFailure = fsRes
        } else {
            // Fallback blind write for models that hide FS! from read-info.
            let mask = UInt16(1 << index)
            var currentMask: UInt16 = 0
            if let existing = readKey(forceKey, dataSize: 2), existing.dataSize >= 2 {
                currentMask = UInt16(existing.bytes[0]) << 8 | UInt16(existing.bytes[1])
            }

            if manual {
                currentMask |= mask
            } else {
                currentMask &= ~mask
            }

            var fsVal = SMCVal()
            fsVal.dataSize = 2
            fsVal.dataType = stringToKey("ui16")
            fsVal.bytes[0] = UInt8((currentMask >> 8) & 0xFF)
            fsVal.bytes[1] = UInt8(currentMask & 0xFF)

            let fsRes = writeKey(forceKey, val: fsVal)
            if fsRes == kIOReturnSuccess {
                hadModeControlKey = true
                lastFailure = kIOReturnSuccess
            } else if fsRes != kIOReturnNotFound {
                return fsRes
            }
        }

        if !hadModeControlKey {
            if !hasLoggedMissingModeKeys {
                logger.notice("Fan mode keys unavailable on this model; target-only fan control will be used")
                hasLoggedMissingModeKeys = true
            }
            return kIOReturnSuccess
        }

        return lastFailure == kIOReturnNotFound ? kIOReturnSuccess : lastFailure
    }

    func setFanTargetRPM(index: Int, rpm: Int) -> kern_return_t {
        guard let info = getInfo("F\(index)Tg") else {
            logger.error("Fan target key F\(index)Tg not found")
            return kIOReturnNotFound
        }

        var val = SMCVal()
        val.dataSize = max(info.size, 2)
        val.dataType = info.type
        writeRPMBytes(to: &val, rpm: rpm)

        return writeKey("F\(index)Tg", val: val)
    }
}

// MARK: - XPC Service Delegate

final class FanHelper: NSObject, FanHelperProtocol {
    private let smcWriter = SMCWriter()

    func ping(withReply reply: @escaping (Bool) -> Void) {
        reply(smcWriter != nil)
    }

    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void) {
        guard let writer = smcWriter else {
            reply(kIOReturnNotOpen)
            return
        }
        let result = writer.setFanMode(index: index, manual: manual)
        reply(result)
    }

    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void) {
        guard let writer = smcWriter else {
            reply(kIOReturnNotOpen)
            return
        }
        let result = writer.setFanTargetRPM(index: index, rpm: rpm)
        reply(result)
    }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let exportedObject = FanHelper()
    private let logger = Logger(
        subsystem: "com.bandan.me.MacOSNetworkFanSpeed.FanService",
        category: "XPC"
    )
    private let allowedClientBundleIdentifiers: Set<String> = [
        "com.bandan.me.MacOSNetworkFanSpeed",
        "cam.bandan.me.MacOSNetworkFanSpeed",
    ]

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard isConnectionAllowed(connection) else {
            logger.error(
                "Rejected XPC client pid=\(connection.processIdentifier, privacy: .public) uid=\(connection.effectiveUserIdentifier, privacy: .public)"
            )
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: FanHelperProtocol.self)
        connection.exportedObject = exportedObject
        connection.resume()
        return true
    }

    private func isConnectionAllowed(_ connection: NSXPCConnection) -> Bool {
        for bundleIdentifier in allowedClientBundleIdentifiers {
            if satisfiesCodeRequirement(connection: connection, bundleIdentifier: bundleIdentifier) {
                return true
            }
        }

        // Development fallback: ad-hoc signed app builds may not carry the expected
        // bundle identifier in code-sign requirements. Allow any non-root client UID.
        if connection.effectiveUserIdentifier > 0 {
            logger.notice(
                "Allowing XPC client via UID fallback pid=\(connection.processIdentifier, privacy: .public) uid=\(connection.effectiveUserIdentifier, privacy: .public)"
            )
            return true
        }

        return false
    }

    private func satisfiesCodeRequirement(
        connection: NSXPCConnection,
        bundleIdentifier: String
    ) -> Bool {
        let attributes = [
            kSecGuestAttributePid: NSNumber(value: connection.processIdentifier)
        ] as CFDictionary

        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code) == errSecSuccess,
            let code
        else {
            return false
        }

        let requirementString = "identifier \"\(bundleIdentifier)\"" as CFString
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementString, SecCSFlags(), &requirement) == errSecSuccess,
            let requirement
        else {
            return false
        }

        return SecCodeCheckValidity(code, SecCSFlags(), requirement) == errSecSuccess
    }
}

// MARK: - Entry point

let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: "com.bandan.me.MacOSNetworkFanSpeed.FanService")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
