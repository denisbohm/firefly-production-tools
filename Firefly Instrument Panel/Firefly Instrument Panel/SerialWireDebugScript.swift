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

    let serialWireInstrumentIdentifier: String
    var serialWireInstrument: SerialWireInstrument? = nil
    var serialWireDebug: FDSerialWireDebug? = nil
    let executable = FDExecutable()
    let cortex = FDCortexM()
    var trace = false
    
    init(fixture: Fixture, presenter: Presenter, serialWireInstrumentIdentifier: String) {
        self.serialWireInstrumentIdentifier = serialWireInstrumentIdentifier
        super.init(fixture: fixture, presenter: presenter)
    }
    
    func setupSerialWireDebug() throws {
        guard let serialWireInstrument = serialWireInstrument else {
            return
        }
        
        presenter.show(message: "attaching to serial wire debug port...")
        try serialWireInstrument.setEnabled(true)
        
        let serialWireDebug = FDSerialWireDebug()
        serialWireDebug.serialWire = serialWireInstrument
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
        serialWireInstrument = fixture.getSerialWireInstrument(serialWireInstrumentIdentifier)
        try setupSerialWireDebug()
    }
    
    func setupExecutable(resource: String, address: UInt32, length: UInt32) throws {
        presenter.show(message: "locating executable resource \(resource)...")
        guard let path = Bundle(for: SerialWireDebugScript.self).path(forResource: resource, ofType: "elf") else {
            throw ScriptError.setupFailure
        }
        presenter.show(message: "reading executable...")
        try executable.load(path)
        executable.sections = executable.combineAllSectionsType(.program, address: address, length: length, pageSize: 4)
        if executable.sections.count != 1 {
            throw ScriptError.setupFailure
        }
        let section = executable.sections[0]

        presenter.show(message: "loading executable into MCU RAM...")
        #if true
        guard let serialWireDebug = self.serialWireDebug else {
            throw ScriptError.setupFailure
        }
        try serialWireDebug.writeMemory(section.address, data: section.data)
        let verify = try serialWireDebug.readMemory(section.address, length: UInt32(section.data.count))
        if verify != section.data {
            for i in 0 ..< verify.count {
                let expected = section.data[i]
                let actual = verify[i]
                if actual != expected {
                    presenter.show(message: "verify failed at offset \(i) expected \(expected) \(actual)")
                }
            }
            throw ScriptError.setupFailure
        }
        #else
        guard
            let fileSystem = fixture.fileSystem,
            let storageInstrument = fixture.storageInstrument,
            let serialWireInstrument = serialWireInstrument
        else {
            throw ScriptError.setupFailure
        }
        let entry = try fileSystem.ensure(resource, data: section.data)
        try serialWireInstrument.writeFromStorage(section.address, length: UInt32(section.data.count), storageIdentifier: storageInstrument.identifier, storageAddress: entry.address)
        try serialWireInstrument.compareToStorage(section.address, length: UInt32(section.data.count), storageIdentifier: storageInstrument.identifier, storageAddress: entry.address)
        #endif
        
        try setupCortex(address: address, length: length, stackSize: 0x1000, heapSize: 0x1000)
    }
    
    func getFunction(name: String) throws -> FDExecutableFunction {
        let functions = executable.functions
        let object = functions[name]
        guard let function = object as? FDExecutableFunction else {
            throw FixtureScript.ScriptError.setupFailure
        }
        return function
    }

    func setupCortex(address: UInt32, length: UInt32, stackSize: UInt32, heapSize: UInt32) throws {
        presenter.show(message: "setting up MCU RPC...")

        cortex.logger = serialWireDebug!.logger
        cortex.serialWireDebug = serialWireDebug
        cortex.breakLocation = try getFunction(name: "halt").address

        let ramStart = Int(address)
        let stackLength = Int(stackSize)
        let heapLength = Int(heapSize)
        
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
        let offset: UInt32
        let name: String
    }
    
    func dump(name: String, base: UInt32, locations: [Location]) throws {
        for location in locations {
            var value: UInt32 = 0
            try serialWireDebug?.readMemory(base + location.offset, value: &value)
            NSLog(String(format: "%08x + %03x = %08x \(name) \(location.name)", base, location.offset, value))
        }
    }
    
    func dumpP0() throws {
        try dump(name: "P0", base: 0x50000000, locations: [
            Location(offset: 0x700, name: "PIN_CNF[0]"),
            Location(offset: 0x704, name: "PIN_CNF[1]"),
            Location(offset: 0x708, name: "PIN_CNF[2]"),
            Location(offset: 0x70c, name: "PIN_CNF[3]"),
            Location(offset: 0x710, name: "PIN_CNF[4]"),
            Location(offset: 0x714, name: "PIN_CNF[5]"),
            Location(offset: 0x718, name: "PIN_CNF[6]"),
            Location(offset: 0x71c, name: "PIN_CNF[7]"),
            ])
    }
    
    func dumpP1() throws {
        try dump(name: "P1", base: 0x50000300, locations: [
            Location(offset: 0x700, name: "PIN_CNF[0]"),
            Location(offset: 0x704, name: "PIN_CNF[1]"),
            Location(offset: 0x708, name: "PIN_CNF[2]"),
            Location(offset: 0x70c, name: "PIN_CNF[3]"),
            Location(offset: 0x710, name: "PIN_CNF[4]"),
            Location(offset: 0x714, name: "PIN_CNF[5]"),
            Location(offset: 0x718, name: "PIN_CNF[6]"),
            Location(offset: 0x71c, name: "PIN_CNF[7]"),
            ])
    }
    
    func dumpTWIM0() throws {
        try dump(name: "TWIM0", base: 0x40003000, locations: [
            Location(offset: 0x104, name: "EVENTS_STOPPED"),
            Location(offset: 0x124, name: "EVENTS_ERROR"),
            Location(offset: 0x148, name: "EVENTS_SUSPENDED"),
            Location(offset: 0x14C, name: "EVENTS_RXSTARTED"),
            Location(offset: 0x150, name: "EVENTS_TXSTARTED"),
            Location(offset: 0x15C, name: "EVENTS_LASTRX"),
            Location(offset: 0x160, name: "EVENTS_LASTTX"),
            Location(offset: 0x200, name: "SHORTS"),
            Location(offset: 0x300, name: "INTEN"),
            Location(offset: 0x4C4, name: "ERRORSRC"),
            Location(offset: 0x500, name: "ENABLE"),
            Location(offset: 0x524, name: "FREQUENCY"),
            Location(offset: 0x534, name: "RXD.PTR"),
            Location(offset: 0x538, name: "RXD.MAXCNT"),
            Location(offset: 0x53C, name: "RXD.AMOUNT"),
            Location(offset: 0x540, name: "RXD.LIST"),
            Location(offset: 0x544, name: "TXD.PTR"),
            Location(offset: 0x548, name: "TXD.MAXCNT"),
            Location(offset: 0x54C, name: "TXD.AMOUNT"),
            Location(offset: 0x550, name: "TXD.LIST"),
            Location(offset: 0x588, name: "ADDRESS"),
            ])
    }
    
    func dumpSPIM2() throws {
        try dump(name: "SPIM2", base: 0x40023000, locations: [
            Location(offset: 0x104, name: "EVENTS_STOPPED"),
            Location(offset: 0x110, name: "EVENTS_ENDRX"),
            Location(offset: 0x118, name: "EVENTS_END"),
            Location(offset: 0x120, name: "EVENTS_ENDTX"),
            Location(offset: 0x14c, name: "EVENTS_STARTED"),
            Location(offset: 0x200, name: "SHORTS"),
            Location(offset: 0x500, name: "ENABLE"),
            Location(offset: 0x508, name: "PSEL.SCK"),
            Location(offset: 0x50c, name: "PSEL.MOSI"),
            Location(offset: 0x510, name: "PSEL.MISO"),
            Location(offset: 0x514, name: "PSEL.CSN"),
            Location(offset: 0x524, name: "FREQUENCY"),
            Location(offset: 0x534, name: "RXD.PTR"),
            Location(offset: 0x538, name: "RXD.MAXCNT"),
            Location(offset: 0x53c, name: "RXD.AMOUNT"),
            Location(offset: 0x540, name: "RXD.LIST"),
            Location(offset: 0x544, name: "TXD.PTR"),
            Location(offset: 0x548, name: "TXD.MAXCNT"),
            Location(offset: 0x54C, name: "TXD.AMOUNT"),
            Location(offset: 0x550, name: "TXD.LIST"),
            Location(offset: 0x554, name: "CONFIG"),
            ])
    }
    
}
