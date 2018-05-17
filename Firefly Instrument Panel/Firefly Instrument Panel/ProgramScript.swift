//
//  ProgramScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/16/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug
import FireflyInstruments

class ProgramScript: SerialWireDebugScript, Script {
    
    enum LocalError: Error {
        case unknownProcessor
        case flashVerificationFailure(detail: String)
        case metadataVerificationFailure
        case configurationVerificationFailure
        case uicrVerificationFailure
    }
    
    let bootFirmware: IntelHex
    let applicationFirmware: IntelHex
    let softdeviceFirmware: IntelHex
    let serialNumber: UInt32
    var flash: FDFireflyFlash? = nil
    
    init(fixture: Fixture, presenter: Presenter, serialWireInstrumentIdentifier: String, boot: IntelHex, application: IntelHex, softdevice: IntelHex, serialNumber: UInt32) {
        self.bootFirmware = boot
        self.applicationFirmware = application
        self.softdeviceFirmware = softdevice
        self.serialNumber = serialNumber
        super.init(fixture: fixture, presenter: presenter, serialWireInstrumentIdentifier: serialWireInstrumentIdentifier)
    }
    
    func programFlash(_ name: String, firmware: IntelHex) throws {
        let programmer = Programmer()
        try programmer.programFlash(presenter: presenter, fixture: fixture, flash: flash!, name: name, firmware: firmware)
    }
    
    func programBoot() throws {
        try programFlash("boot", firmware: bootFirmware)
    }
    
    func programApplication() throws {
        try programFlash("application", firmware: applicationFirmware)
    }
    
    func programSoftdevice() throws {
        try programFlash("softdevice", firmware: softdeviceFirmware)
    }
    
    static let UICR = UInt32(0x10001000)
    
    static let BOOTLOADERADDR = UInt32(0x014)
    static let UICR_BOOTLOADERADDR = UICR + BOOTLOADERADDR
    
    static let CUSTOMER = UInt32(0x080)
    static let UICR_CUSTOMER = UICR + CUSTOMER
    
    static let PSELRESET0 = UInt32(0x200)
    static let UICR_PSELRESET0 = UICR + PSELRESET0
    static let PSELRESET1 = UInt32(0x204)
    static let UICR_PSELRESET1 = UICR + PSELRESET1
    
    static let NFCPINSADDR = UInt32(0x20C)
    static let UICR_NFCPINS = UICR + NFCPINSADDR
    
    static func set(_ data: inout Data, index: inout UInt32, value: UInt8) {
        data[Int(index)] = value
        index += 1
    }
    
    func programManufacturingInformation() throws {
        guard let flash = flash, let serialWireDebug = serialWireDebug else {
            return
        }
        
        var data = try serialWireDebug.readMemory(ProgramScript.UICR, length:flash.pageSize)
        
        var index = ProgramScript.BOOTLOADERADDR
        let (bootAddressBounds, _) = try bootFirmware.combineData()
        let bootloaderAddress = bootAddressBounds.min
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: bootloaderAddress))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: bootloaderAddress >> 8))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: bootloaderAddress >> 16))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: bootloaderAddress >> 24))
        
        let pselreset = 0x80000000 | UInt32(18) // setup P0.18 as reset pin
        index = ProgramScript.PSELRESET0
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset >> 8))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset >> 16))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset >> 24))
        index = ProgramScript.PSELRESET1
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset >> 8))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset >> 16))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: pselreset >> 24))
        
        let ncfpins = UInt32(0xfffffffe) // NCF pins operate as GPIO (not as NCF)
        index = ProgramScript.NFCPINSADDR
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: ncfpins & 0xff))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: ncfpins >> 8))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: ncfpins >> 16))
        ProgramScript.set(&data, index: &index, value: UInt8(truncatingIfNeeded: ncfpins >> 24))
        
        let productionDate = UInt32(Date().timeIntervalSince1970)
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(serialNumber)
        binary.write("SN\0\0".data(using: .utf8)!)
        binary.write(productionDate)
        binary.write("PD\0\0".data(using: .utf8)!)
        let manufacturingInformation = binary.data
        data.replaceSubrange(Int(ProgramScript.CUSTOMER) ..< Int(ProgramScript.CUSTOMER) + manufacturingInformation.count, with: manufacturingInformation)
        
        let flashNRF5 = flash as! FDFireflyFlashNRF5
        try flashNRF5.eraseUICR()
        try flash.writePages(ProgramScript.UICR, data: data, erase: false)
        let verify = try serialWireDebug.readMemory(ProgramScript.UICR, length: flash.pageSize)
        let programmer = Programmer()
        programmer.programResult(presenter: presenter, name: "ManufacturingInformation", data: data, verify: verify)
    }
    
    override func setup() throws {
        try super.setup()
        let programmer = Programmer()
        flash = try programmer.setupFlash(serialWireDebugScript: self)
    }
    
    func main() throws {
        try programBoot()
        try programApplication()
        try programSoftdevice()
        try programManufacturingInformation()
    }

}
