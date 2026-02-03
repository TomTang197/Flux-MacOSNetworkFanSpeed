//
//  main.swift
//  FanPrivilegedHelper
//
//  Created by Bandan.K on 03/02/26.
//

import Foundation
import IOKit

// MARK: - XPC Protocol (helper side)

@objc protocol FanHelperProtocol {
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
}

// MARK: - SMC Low-Level Implementation (write-focused)

final class SMCWriter {
    private var connection: io_connect_t = 0

    init?() {
        guard open() else { return nil }
    }

    deinit {
        close()
    }

    private func open() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            return false
        }

        // Type 2 is required for privileged writes on Apple Silicon.
        let result = IOServiceOpen(service, mach_task_self_, 2, &connection)
        IOObjectRelease(service)

        return result == kIOReturnSuccess && connection != 0
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
        case writeValue = 6
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

    private func writeKey(_ name: String, val: SMCVal) -> kern_return_t {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToKey(name)
        inputStruct.dataSize = val.dataSize
        inputStruct.dataType = val.dataType
        inputStruct.dataAttributes = 0x80  // required for some writes on Apple Silicon

        // Copy bytes into tuple
        for (i, byte) in val.bytes.enumerated() {
            if i >= 32 { break }
            withUnsafeMutablePointer(to: &inputStruct.bytes) { pointer in
                let bPointer = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
                bPointer[i] = byte
            }
        }

        let res = callSMC(.writeValue, inputStruct: &inputStruct)
        return (res == kIOReturnSuccess && inputStruct.result == 0) ? res : res
    }

    // MARK: - Public fan helpers

    func setFanMode(index: Int, manual: Bool) -> kern_return_t {
        var val = SMCVal()
        val.dataSize = 1
        val.dataType = stringToKey("ui8 ")
        val.bytes[0] = manual ? 1 : 0

        let modeRes = writeKey("F\(index)Md", val: val)

        // Also toggle FS! bitmask when possible.
        // If FS! write fails due to privilege, the main mode write result still matters most.
        var fsVal = SMCVal()
        fsVal.dataSize = 2
        fsVal.dataType = stringToKey("ui16")

        // Very simple mask: set or clear this fan's bit.
        let mask = UInt16(1 << index)
        var currentMask: UInt16 = 0
        if manual {
            currentMask |= mask
        } else {
            currentMask &= ~mask
        }
        fsVal.bytes[0] = UInt8((currentMask >> 8) & 0xFF)
        fsVal.bytes[1] = UInt8(currentMask & 0xFF)
        _ = writeKey("FS! ", val: fsVal)

        return modeRes
    }

    func setFanTargetRPM(index: Int, rpm: Int) -> kern_return_t {
        // Encode as fpe2 (RPM * 4) – matches common fan target encoding.
        var val = SMCVal()
        val.dataSize = 2
        val.dataType = stringToKey("fpe2")

        let encoded = UInt16(rpm << 2)
        val.bytes[0] = UInt8((encoded >> 8) & 0xFF)
        val.bytes[1] = UInt8(encoded & 0xFF)

        return writeKey("F\(index)Tg", val: val)
    }
}

// MARK: - XPC Service Delegate

final class FanHelper: NSObject, FanHelperProtocol {
    private let smcWriter = SMCWriter()

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

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: FanHelperProtocol.self)
        connection.exportedObject = exportedObject
        connection.resume()
        return true
    }
}

// MARK: - Entry point

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
