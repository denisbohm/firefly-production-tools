//
//  SerialWireDebugScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments

class SerialWireDebugScript: FixtureScript {

    var serialWireDebug: FDSerialWireDebug? = nil
    let executable = FDExecutable()
    let cortex = FDCortexM()
    var trace = true
    
    func setupSerialWireDebug() throws {
        presenter.show(message: "attaching to serial wire debug port...")
        try fixture.serialWireInstrument?.setEnabled(true)
        
        let serialWireDebug = FDSerialWireDebug()
        serialWireDebug.serialWire = fixture.serialWireInstrument!
        let serialWire = serialWireDebug.serialWire!
        serialWire.setReset(true)
        try serialWire.write()
        Thread.sleep(forTimeInterval: 0.1)
        serialWire.setReset(false)
        try serialWire.write()
        Thread.sleep(forTimeInterval: 1.0)
        
        serialWireDebug.resetDebugPort()
        try serialWire.write()
        
        var debugPortIDCode: UInt32 = 0
        try serialWireDebug.readPortIDCode(&debugPortIDCode)
        NSLog(FDSerialWireDebug.debugPortIDCodeDescription(debugPortIDCode))
        
        try serialWireDebug.initializeDebugPort()
        try serialWireDebug.halt()
        
        // !!! In "fresh" EFM32 boards there seem to be interrupts pending, this seems to clear it (this needs more investigation) -denis
        try serialWireDebug.writeMemory(0xE000ED0C, value: 0x05FA0001)
        try serialWireDebug.step()
        
        try serialWireDebug.initializeAccessPort()
        
        self.serialWireDebug = serialWireDebug
    }
    
    override func setup() throws {
        try super.setup()
        try setupSerialWireDebug()
    }
    
    func setupExecutable(resource: String) throws {
        presenter.show(message: "locating executable resource \(resource)...")
        guard let path = Bundle(for: SerialWireDebugScript.self).path(forResource: resource, ofType: "elf") else {
            throw ScriptError.setupFailure
        }
        presenter.show(message: "reading executable...")
        try executable.load(path)
        executable.sections = executable.combineAllSectionsType(.program, address: 0x20000000, length: 0x40000, pageSize: 4)
        let section = executable.sections[0]
        let data = section.data
        let length = UInt32(data.count)

        presenter.show(message: "loading executable into MCU RAM...")
        guard
            let fileSystem = fixture.fileSystem,
            let storageInstrument = fixture.storageInstrument,
            let serialWireInstrument = fixture.serialWireInstrument
        else {
            throw ScriptError.setupFailure
        }
        let entry = try fileSystem.ensure(resource, data: data)
        try serialWireInstrument.writeFromStorage(section.address, length: length, storageIdentifier: storageInstrument.identifier, storageAddress: entry.address)
        try serialWireInstrument.compareToStorage(section.address, length: length, storageIdentifier: storageInstrument.identifier, storageAddress: entry.address)
        
        try setupCortex()
    }
    
    func getFunction(name: String) throws -> FDExecutableFunction {
        let functions = executable.functions
        let object = functions[name]
        guard let function = object as? FDExecutableFunction else {
            throw FixtureScript.ScriptError.setupFailure
        }
        return function
    }

    func setupCortex() throws {
        presenter.show(message: "setting up MCU RPC...")

        cortex.logger = serialWireDebug!.logger
        cortex.serialWireDebug = serialWireDebug
        cortex.breakLocation = try getFunction(name: "halt").address

        let ramStart = 0x20000000
        let stackLength = 0x1000
        let heapLength = 0x1000
        
        var programAddressEnd = ramStart
        for section in executable.sections {
            switch section.type {
            case .data, .program:
                let sectionAddressEnd = Int(section.address) + section.data.count
                if sectionAddressEnd > programAddressEnd {
                    programAddressEnd = sectionAddressEnd
                }
            }
        }
        let programLength = programAddressEnd - ramStart
        let codeLength = (programLength + 3) & ~0x03
        let ramLength = codeLength + stackLength + heapLength
        
        cortex.programRange.location = UInt32(ramStart)
        cortex.programRange.length = UInt32(programLength)
        cortex.stackRange.location = UInt32(ramStart + ramLength - stackLength)
        cortex.stackRange.length = UInt32(stackLength)
        cortex.heapRange.location = cortex.stackRange.location - UInt32(heapLength)
        cortex.heapRange.length = UInt32(heapLength)
        if cortex.heapRange.location < (cortex.programRange.location + cortex.programRange.length) {
            throw FixtureScript.ScriptError.setupFailure
        }
    }
    
    func run(_ address: UInt32, r0: UInt32 = 0, r1: UInt32 = 0, r2: UInt32 = 0, r3: UInt32 = 0, timeout: TimeInterval = 1.0) throws -> UInt32 {
        try cortex.setupCall(address, r0: r0, r1: r1, r2: r2, r3: r3, run: !trace)
        var resultR0: UInt32 = 0
        if trace {
            var pc: UInt32 = 0
            while true {
                try serialWireDebug?.readRegister(UInt16(CORTEX_M_REGISTER_PC), value: &pc)
                if pc == cortex.breakLocation {
                    break
                }
                NSLog("pc %08x", pc)
                try serialWireDebug?.step()
            }
            try serialWireDebug?.readRegister(UInt16(CORTEX_M_REGISTER_R0), value: &resultR0)
        } else {
            try cortex.wait(forHalt: timeout, resultR0: &resultR0)
        }
        return resultR0
    }
    
    struct Location {
        let base: UInt32
        let offset: UInt32
        let name: String
    }
    
    func dump(locations: [Location]) throws {
        for location in locations {
            var value: UInt32 = 0
            try serialWireDebug?.readMemory(location.base + location.offset, value: &value)
            NSLog(String(format: "%08x + %03x = %08x \(location.name)", location.base, location.offset, value))
        }
    }
    
    func dumpTWIM0() throws {
        try dump(locations: [
            Location(base: 0x40003000, offset: 0x104, name: "TWM0 EVENTS_STOPPED"),
            Location(base: 0x40003000, offset: 0x124, name: "TWM0 EVENTS_ERROR"),
            Location(base: 0x40003000, offset: 0x148, name: "TWM0 EVENTS_SUSPENDED"),
            Location(base: 0x40003000, offset: 0x14C, name: "TWM0 EVENTS_RXSTARTED"),
            Location(base: 0x40003000, offset: 0x150, name: "TWM0 EVENTS_TXSTARTED"),
            Location(base: 0x40003000, offset: 0x15C, name: "TWM0 EVENTS_LASTRX"),
            Location(base: 0x40003000, offset: 0x160, name: "TWM0 EVENTS_LASTTX"),
            Location(base: 0x40003000, offset: 0x200, name: "TWM0 SHORTS"),
            Location(base: 0x40003000, offset: 0x300, name: "TWM0 INTEN"),
            Location(base: 0x40003000, offset: 0x4C4, name: "TWM0 ERRORSRC"),
            Location(base: 0x40003000, offset: 0x500, name: "TWM0 ENABLE"),
            Location(base: 0x40003000, offset: 0x524, name: "TWM0 FREQUENCY"),
            Location(base: 0x40003000, offset: 0x534, name: "TWM0 RXD.PTR"),
            Location(base: 0x40003000, offset: 0x538, name: "TWM0 RXD.MAXCNT"),
            Location(base: 0x40003000, offset: 0x53C, name: "TWM0 RXD.AMOUNT"),
            Location(base: 0x40003000, offset: 0x540, name: "TWM0 RXD.LIST"),
            Location(base: 0x40003000, offset: 0x544, name: "TWM0 TXD.PTR"),
            Location(base: 0x40003000, offset: 0x548, name: "TWM0 TXD.MAXCNT"),
            Location(base: 0x40003000, offset: 0x54C, name: "TWM0 TXD.AMOUNT"),
            Location(base: 0x40003000, offset: 0x550, name: "TWM0 TXD.LIST"),
            Location(base: 0x40003000, offset: 0x588, name: "TWM0 ADDRESS"),
            ])
    }
    
}
