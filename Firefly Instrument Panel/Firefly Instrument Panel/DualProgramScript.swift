//
//  DualProgramScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 9/4/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug
import FireflyInstruments

class DualProgramScript: FixtureScript, Script {

    enum LocalError: Error {
        case conversionError
    }
    
    let nrf5BootFirmware: IntelHex
    let nrf5ApplicationFirmware: IntelHex
    let nrf5SoftdeviceFirmware: IntelHex
    let serialNumber: UInt32
    let apolloApplicationFirmware: IntelHex
    
    init(fixture: Fixture, presenter: Presenter, nrf5Boot: IntelHex, nrf5Application: IntelHex, nrf5Softdevice: IntelHex, serialNumber: UInt32, apolloApplication: IntelHex) {
        self.nrf5BootFirmware = nrf5Boot
        self.nrf5ApplicationFirmware = nrf5Application
        self.nrf5SoftdeviceFirmware = nrf5Softdevice
        self.serialNumber = serialNumber
        self.apolloApplicationFirmware = apolloApplication
        super.init(fixture: fixture, presenter: presenter)
    }
    
    func programNRF5() throws {
        let programScript = ProgramScript(fixture: fixture, presenter: presenter, serialWireInstrumentIdentifier: "SerialWire1", boot: nrf5BootFirmware, application: nrf5ApplicationFirmware, softdevice: nrf5SoftdeviceFirmware, serialNumber: serialNumber)
        programScript.doSetupInstruments = false
        try programScript.setup()
        try programScript.main()
    }
    
    func programApollo() throws {
        let serialWireDebugScript = SerialWireDebugScript(fixture: fixture, presenter: presenter, serialWireInstrumentIdentifier: "SerialWire2")
        serialWireDebugScript.doSetupInstruments = false
        try serialWireDebugScript.setup()
        
        let programmer = Programmer()
        let flash = try programmer.setupFlash(serialWireDebugScript: serialWireDebugScript, processor: "APOLLO")
        presenter.show(message: "erasing apollo...")
        try flash.massErase()
        presenter.show(message: "apollo erased")
        
        try programmer.programFlash(presenter: presenter, fixture: fixture, flash: flash, name: "apollo_display", firmware: apolloApplicationFirmware)
        
        try serialWireDebugScript.serialWireInstrument?.setEnabled(false)
    }
    
    func powerCycle() throws {
        presenter.show(message: "cycling battery power...")
        try fixture.simulatorToBatteryRelayInstrument?.set(false)
        Thread.sleep(forTimeInterval: 1.0)
        try fixture.simulatorToBatteryRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 2.0)
    }
    
    func measure() throws {
        do {
            try fixture.voltageSenseRelayInstrument?.set(true)
            Thread.sleep(forTimeInterval: 1.0)
            let conversion = try fixture.voltageInstrument?.convert()
            try fixture.voltageSenseRelayInstrument?.set(false)
            let voltage = conversion?.voltage ?? 0
            presenter.show(message: "system voltage \(voltage)")
        }
        guard let conversion = try fixture.batteryInstrument?.convert() else {
            throw LocalError.conversionError
        }
        presenter.show(message: "system current \(conversion.current)")
    }
    
    override func setup() throws {
        try super.setup()
    }
    
    func main() throws {
        try setup()
        try programNRF5()
        try programApollo()
        try powerCycle()
        try measure()
    }
    
}
