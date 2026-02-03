//
//  SMCService.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import Foundation
import IOKit

class SMCService {
    static let shared = SMCService()
    private var connection: io_connect_t = 0
    var isConnected: Bool { connection != 0 }
    var lastError: String?

    struct SMCKey {
        let code: String
        let info: String
    }

    private init() {
        open()
    }

    deinit {
        close()
    }

    func reconnect() {
        close()
        open()
    }

    private func open() {
        print("📡 SMC: Searching for AppleSMC service...")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))

        if service == 0 {
            lastError = "AppleSMC Service not found. Entitlements/Sandbox might be blocking access."
            print("❌ SMC: \(lastError!)")
            return
        }

        print("📡 SMC: AppleSMC Service found (ID: \(service))")

        // Try both connection types. Type 1 is often required for modern Silicon index 2 calls.
        var success = false
        for type in [UInt32(1), 0] {
            print("📡 SMC: Attempting IOServiceOpen with type \(type)...")
            let result = IOServiceOpen(service, mach_task_self_, type, &connection)
            if result == kIOReturnSuccess {
                print("✅ SMC: Connected successfully (Type \(type), ID: \(connection))")
                success = true
                break
            } else {
                print("ℹ️ SMC: Connection type \(type) failed (Error: \(result))")
            }
        }

        IOObjectRelease(service)

        if !success {
            lastError = "Connection failed. Try disabling App Sandbox or check entitlements."
            print("❌ SMC: All connection attempts failed.")
            connection = 0
        } else {
            lastError = nil
            unlockSiliconDiagnostics()
        }
    }

    private func unlockSiliconDiagnostics() {
        var val = SMCVal()
        val.dataSize = 1
        val.dataType = stringToKey("ui8 ")
        val.bytes[0] = 1

        let res = writeKey("Ftst", val: val)
        if res == kIOReturnSuccess {
            print("💎 SMC: Diagnostic mode (Ftst) unlocked")
        } else {
            print("⚠️ SMC: Ftst lock status (Result: \(res)) - Some models may not require this.")
        }
    }

    private func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    // MARK: - SMC Data Structures

    struct SMCVal {
        var key: UInt32 = 0
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var bytes: [UInt8] = Array(repeating: 0, count: 32)
    }

    // Fixed-size 80-byte structure required for Apple Silicon (ARM64)
    // Fixed-size 80-byte structure required for Apple Silicon (ARM64) Method Index 2
    struct SMCParamStruct {
        var key: UInt32 = 0  // Offset 0
        // Version fields
        var major: UInt8 = 0  // 4
        var minor: UInt8 = 0  // 5
        var build: UInt8 = 0  // 6
        var reserved: UInt8 = 0  // 7
        var release: UInt16 = 0  // 8
        // PLimit fields
        var plLimitVersion: UInt16 = 0  // 10
        var plLimitLength: UInt16 = 0  // 12
        var cpuPLimit: UInt32 = 0  // 16 (Aligned)
        var gpuPLimit: UInt32 = 0  // 20
        var memPLimit: UInt32 = 0  // 24
        // KeyInfo fields
        var dataSize: UInt32 = 0  // 28 (Aligned)
        var dataType: UInt32 = 0  // 32 (Aligned)
        var dataAttributes: UInt8 = 0  // 36
        // Padding/Result fields
        var res1: UInt8 = 0  // 37
        var res2: UInt16 = 0  // 38 (Aligned)
        var result: UInt8 = 0  // 40
        var status: UInt8 = 0  // 41
        var data8: UInt8 = 0  // 42 (Command)
        var res3: UInt8 = 0  // 43
        var data32: UInt32 = 0  // 44 (Aligned)
        var bytes:
            (
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
            ) = (
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0
            )  // Offset 48, total 80 bytes
    }

    enum SMCSelector: UInt32 {
        case callMethod = 2  // Gateway for Apple Silicon
        case readInfo = 9
        case readValueLegacy = 5
        case writeValueLegacy = 6
    }

    enum SMCCmd: UInt8 {
        case readValue = 5
        case writeValue = 6
        case readInfo = 9
    }

    // MARK: - Low Level API

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

    private func stringToKey(_ name: String) -> UInt32 {
        var key: UInt32 = 0
        for char in name.utf8 {
            key = (key << 8) | UInt32(char)
        }
        return key
    }

    private func getInfo(_ name: String) -> (size: UInt32, type: UInt32)? {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)

        let result = callSMC(.readInfo, inputStruct: &inputStruct)
        if result == kIOReturnSuccess {
            return (inputStruct.dataSize, inputStruct.dataType)
        }
        return nil
    }

    func readKey(_ name: String) -> SMCVal? {
        let info = getInfo(name)

        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = info?.size ?? 2

        let result = callSMC(.readValue, inputStruct: &inputStruct)

        if result == kIOReturnSuccess && inputStruct.result == 0 {
            var val = SMCVal()
            val.key = inputStruct.key
            val.dataSize = inputStruct.dataSize
            val.dataType = info?.type ?? inputStruct.dataType
            val.bytes = withUnsafeBytes(of: inputStruct.bytes) { Array($0) }
            return val
        }

        // Blind fallback for common data sizes if info failed
        if info == nil {
            for size in [UInt32(1), 4] {
                inputStruct.dataSize = size
                if callSMC(.readValue, inputStruct: &inputStruct) == kIOReturnSuccess
                    && inputStruct.result == 0
                {
                    var val = SMCVal()
                    val.key = inputStruct.key
                    val.dataSize = inputStruct.dataSize
                    val.dataType = 0
                    val.bytes = withUnsafeBytes(of: inputStruct.bytes) { Array($0) }
                    return val
                }
            }
        }

        return nil
    }

    private func keyToString(_ key: UInt32) -> String {
        let bytes = [
            UInt8((key >> 24) & 0xFF),
            UInt8((key >> 16) & 0xFF),
            UInt8((key >> 8) & 0xFF),
            UInt8(key & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }

    // MARK: - Conversions

    func bytesToFloat(_ val: SMCVal) -> Float {
        let type = val.dataType
        let bytes = val.bytes

        if type == stringToKey("sp78") {
            // Signed 7.8 fixed point
            return Float(Int16(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
        } else if type == stringToKey("fpe2") {
            // Unsigned 14.2 fixed point
            return Float(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        } else if type == stringToKey("flt ") {
            var floatVal: Float = 0
            memcpy(&floatVal, bytes, 4)
            return floatVal
        } else if type == stringToKey("ui16") {
            return Float(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        } else if type == stringToKey("ui32") {
            return Float(
                UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            )
        } else if type == stringToKey("ui8 ") {
            return Float(bytes[0])
        }

        // Smart fallback for unknown types (e.g. if getInfo failed)
        if val.dataSize == 2 {
            let high = bytes[0]
            // sp78 (temperature) logic: high byte is usually the integer part.
            // If it's a realistic temperature (10-120°C), treat as sp78.
            if high >= 10 && high < 120 {
                return Float(Int16(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
            }
            // Otherwise, it might be RPM (fpe2)
            return Float(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        }

        return 0
    }

    func writeKey(_ name: String, val: SMCVal) -> kern_return_t {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = val.dataSize
        inputStruct.dataType = val.dataType

        // Critical for Apple Silicon: some writes require 0x80 attribute
        inputStruct.dataAttributes = 0x80

        // Copy array to tuple
        for (i, byte) in val.bytes.enumerated() {
            if i >= 32 { break }
            withUnsafeMutablePointer(to: &inputStruct.bytes) { pointer in
                let bPointer = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
                bPointer[i] = byte
            }
        }

        let res = callSMC(.writeValue, inputStruct: &inputStruct)
        if res != kIOReturnSuccess || inputStruct.result != 0 {
            print("❌ SMC: Write to '\(name)' failed (Result: \(res), SMC: \(inputStruct.result))")
        }
        return res
    }

    // MARK: - High Level API

    func getFanRPM(_ index: Int) -> Int? {
        // Try standard Intel-style key first, then Silicon-style
        if let val = readKey("F\(index)Ac") {
            return Int(bytesToFloat(val))
        }
        if let val = readKey("Fan\(index)") {
            return Int(bytesToFloat(val))
        }
        return nil
    }

    func setFanMode(_ index: Int, manual: Bool) {
        // 1. Set per-fan mode (legacy/Intel)
        var val = SMCVal()
        val.dataSize = 1
        val.dataType = stringToKey("ui8 ")
        val.bytes[0] = manual ? 1 : 0
        _ = writeKey("F\(index)Md", val: val)

        // 2. Set System Force bitmask (Apple Silicon override)
        if let currentFS = readKey("FS! ") {
            var newFS = currentFS
            if newFS.dataSize < 2 { newFS.dataSize = 2 }

            let mask = UInt16(1 << index)
            var currentMask = UInt16(newFS.bytes[0]) << 8 | UInt16(newFS.bytes[1])

            if manual {
                currentMask |= mask
            } else {
                currentMask &= ~mask
            }

            newFS.bytes[0] = UInt8((currentMask >> 8) & 0xFF)
            newFS.bytes[1] = UInt8(currentMask & 0xFF)
            _ = writeKey("FS! ", val: newFS)
        }
    }

    func setFanTargetRPM(_ index: Int, rpm: Int) {
        let targetKey = "F\(index)Tg"
        guard let info = getInfo(targetKey) else { return }

        var val = SMCVal()
        val.dataSize = info.size
        val.dataType = info.type

        if info.type == stringToKey("fpe2") {
            let encoded = UInt16(rpm << 2)
            val.bytes[0] = UInt8((encoded >> 8) & 0xFF)
            val.bytes[1] = UInt8(encoded & 0xFF)
        } else {
            val.bytes[0] = UInt8((rpm >> 8) & 0xFF)
            val.bytes[1] = UInt8(rpm & 0xFF)
        }

        _ = writeKey(targetKey, val: val)
    }

    func getTemperature(_ key: String) -> Double? {
        guard let val = readKey(key) else { return nil }
        let temp = Double(bytesToFloat(val))
        // Sanity check for temperatures
        return (temp > 0 && temp < 150) ? temp : nil
    }
}
