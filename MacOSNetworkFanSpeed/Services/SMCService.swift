//
//  SMCService.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//  Modified for Read-Only monitoring on 14/02/26.
//

import Foundation
import IOKit

class SMCService {
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
        open()
    }

    private func open() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service == 0 {
            lastError = "AppleSMC Service not found."
            return
        }

        // Connection type 0 is sufficient for reading sensors
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)

        if result != kIOReturnSuccess {
            lastError = "Connection failed."
            connection = 0
        } else {
            lastError = nil
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

    // 80-byte structure for Apple Silicon
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
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private func callSMC(_ selector: UInt32, inputStruct: inout SMCParamStruct) -> kern_return_t {
        guard connection != 0 else { return kIOReturnNotOpen }
        let inputSize = MemoryLayout<SMCParamStruct>.size
        var outputStruct = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(connection, selector, &inputStruct, inputSize, &outputStruct, &outputSize)
        if result == kIOReturnSuccess { inputStruct = outputStruct }
        return result
    }

    private func stringToKey(_ name: String) -> UInt32 {
        var key: UInt32 = 0
        for char in name.utf8 { key = (key << 8) | UInt32(char) }
        return key
    }

    private func getInfo(_ name: String) -> (size: UInt32, type: UInt32)? {
        keyInfoCacheLock.lock()
        if let cached = keyInfoCache[name] {
            keyInfoCacheLock.unlock()
            return cached
        }
        keyInfoCacheLock.unlock()

        var input = SMCParamStruct()
        input.key = stringToKey(name)
        input.data8 = 9 // ReadInfo selector

        if callSMC(2, inputStruct: &input) == kIOReturnSuccess {
            let info = (input.dataSize, input.dataType)
            keyInfoCacheLock.lock()
            keyInfoCache[name] = info
            keyInfoCacheLock.unlock()
            return info
        }
        return nil
    }

    func readKey(_ name: String) -> SMCVal? {
        guard let info = getInfo(name) else { return nil }

        var input = SMCParamStruct()
        input.key = stringToKey(name)
        input.dataSize = info.size
        input.data8 = 5 // ReadValue selector

        if callSMC(2, inputStruct: &input) == kIOReturnSuccess && input.result == 0 {
            var val = SMCVal()
            val.key = input.key
            val.dataSize = input.dataSize
            val.dataType = info.type
            val.bytes = withUnsafeBytes(of: input.bytes) { Array($0) }
            return val
        }
        return nil
    }

    func bytesToFloat(_ val: SMCVal) -> Float {
        let bytes = val.bytes
        if val.dataType == stringToKey("sp78") {
            return Float(Int16(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
        } else if val.dataType == stringToKey("fpe2") {
            return Float(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        }
        return 0
    }

    func getFanRPM(_ index: Int) -> Int? {
        if let val = readKey("F\(index)Ac") {
            let rpm = Int(bytesToFloat(val))
            return rpm > 0 ? rpm : nil
        }
        return nil
    }

    func getTemperature(_ key: String) -> Double? {
        guard let val = readKey(key) else { return nil }
        let temp = Double(bytesToFloat(val))
        return (temp > 0 && temp < 150) ? temp : nil
    }
}
