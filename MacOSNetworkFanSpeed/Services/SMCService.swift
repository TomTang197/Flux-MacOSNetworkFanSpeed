//
//  SMCService.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//  Updated for broader AppleSMC read compatibility on 14/02/26.
//

import Foundation
import IOKit

final class SMCService {
    static let shared = SMCService()

    private var connection: io_connect_t = 0
    private var keyInfoCache: [String: (size: UInt32, type: UInt32)] = [:]
    private let keyInfoCacheLock = NSLock()

    var isConnected: Bool { connection != 0 }
    var lastError: String?

    private init() {
        open()
    }

    deinit {
        close()
    }

    func reconnect() {
        close()
        clearCache()
        open()
    }

    private func open() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            lastError = "AppleSMC Service not found."
            return
        }

        var opened = false
        var lastResult: kern_return_t = kIOReturnError

        // Some Macs read better with type 1, others with type 0.
        for type in [UInt32(1), 0] {
            lastResult = IOServiceOpen(service, mach_task_self_, type, &connection)
            if lastResult == kIOReturnSuccess, connection != 0 {
                opened = true
                break
            }
        }

        IOObjectRelease(service)

        if opened {
            lastError = nil
        } else {
            connection = 0
            lastError = "Connection failed (\(lastResult))."
        }
    }

    private func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    private func clearCache() {
        keyInfoCacheLock.lock()
        keyInfoCache.removeAll()
        keyInfoCacheLock.unlock()
    }

    // MARK: - SMC data structures

    struct SMCVal {
        var key: UInt32 = 0
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var bytes: [UInt8] = Array(repeating: 0, count: 32)
    }

    // 80-byte structure used by modern AppleSMC calls.
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
        var bytes: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private enum SMCSelector: UInt32 {
        case callMethod = 2
    }

    private enum SMCCmd: UInt8 {
        case readValue = 5
        case writeValue = 6
        case readInfo = 9
    }

    private func callSMC(_ cmd: SMCCmd, inputStruct: inout SMCParamStruct) -> kern_return_t {
        guard connection != 0 else { return kIOReturnNotOpen }

        inputStruct.data8 = cmd.rawValue
        let inputSize = MemoryLayout<SMCParamStruct>.size
        var outputStruct = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            connection,
            SMCSelector.callMethod.rawValue,
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
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
        keyInfoCacheLock.lock()
        if let cached = keyInfoCache[name] {
            keyInfoCacheLock.unlock()
            return cached
        }
        keyInfoCacheLock.unlock()

        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)

        guard callSMC(.readInfo, inputStruct: &inputStruct) == kIOReturnSuccess else { return nil }
        guard inputStruct.dataSize > 0 else { return nil }

        let info = (size: inputStruct.dataSize, type: inputStruct.dataType)

        keyInfoCacheLock.lock()
        keyInfoCache[name] = info
        keyInfoCacheLock.unlock()

        return info
    }

    private func readKey(_ name: String, dataSize: UInt32, dataType: UInt32 = 0) -> SMCVal? {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = dataSize

        guard callSMC(.readValue, inputStruct: &inputStruct) == kIOReturnSuccess else { return nil }
        guard inputStruct.result == 0 else { return nil }

        var value = SMCVal()
        value.key = inputStruct.key
        value.dataSize = inputStruct.dataSize
        value.dataType = dataType != 0 ? dataType : inputStruct.dataType
        value.bytes = withUnsafeBytes(of: inputStruct.bytes) { Array($0) }
        return value
    }

    func readKey(_ name: String) -> SMCVal? {
        if let info = getInfo(name),
            let value = readKey(name, dataSize: max(info.size, 1), dataType: info.type)
        {
            return value
        }

        // Compatibility fallback when readInfo is unavailable for a key.
        for fallbackSize in [UInt32(1), 2, 4, 8] {
            if let value = readKey(name, dataSize: fallbackSize) {
                return value
            }
        }

        return nil
    }

    func bytesToFloat(_ value: SMCVal) -> Float {
        let bytes = value.bytes
        let type = value.dataType

        if type == stringToKey("sp78") {
            return Float(Int16(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
        }

        if type == stringToKey("fpe2") {
            return Float(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        }

        if type == stringToKey("flt ") {
            var floatValue: Float = 0
            memcpy(&floatValue, bytes, 4)
            return floatValue
        }

        if type == stringToKey("ui16") {
            return Float(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        }

        if type == stringToKey("ui32") {
            return Float(
                UInt32(bytes[0]) << 24
                    | UInt32(bytes[1]) << 16
                    | UInt32(bytes[2]) << 8
                    | UInt32(bytes[3])
            )
        }

        if type == stringToKey("ui8 ") {
            return Float(bytes[0])
        }

        // Unknown type fallback.
        if value.dataSize == 2 {
            let high = bytes[0]
            if high >= 10 && high < 120 {
                return Float(Int16(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
            }
            return Float(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        }

        if value.dataSize >= 4 {
            var floatValue: Float = 0
            memcpy(&floatValue, bytes, 4)
            if floatValue.isFinite {
                return floatValue
            }
        }

        return 0
    }

    func getFanRPM(_ index: Int) -> Int? {
        for key in ["F\(index)Ac", "Fan\(index)"] {
            if let value = readKey(key) {
                let rpm = Int(bytesToFloat(value))
                if rpm > 0 {
                    return rpm
                }
            }
        }
        return nil
    }

    func getTemperature(_ key: String) -> Double? {
        guard let value = readKey(key) else { return nil }
        let temperature = Double(bytesToFloat(value))
        guard temperature > 0, temperature < 150 else { return nil }
        return temperature
    }

    // Kept for compatibility with helper/future write path.
    func writeKey(_ name: String, value: SMCVal) -> kern_return_t {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = value.dataSize
        inputStruct.dataType = value.dataType
        inputStruct.dataAttributes = 0x80

        for (index, byte) in value.bytes.enumerated() where index < 32 {
            withUnsafeMutablePointer(to: &inputStruct.bytes) { pointer in
                let bytesPointer = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
                bytesPointer[index] = byte
            }
        }

        let result = callSMC(.writeValue, inputStruct: &inputStruct)
        guard result == kIOReturnSuccess else { return result }
        return inputStruct.result == 0 ? kIOReturnSuccess : kIOReturnError
    }
}
