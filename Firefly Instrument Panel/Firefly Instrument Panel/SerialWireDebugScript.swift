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
    
}
