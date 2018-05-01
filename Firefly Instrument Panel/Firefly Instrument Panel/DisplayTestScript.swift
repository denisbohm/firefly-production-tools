//
//  DisplayTestScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/1/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments

class DisplayTestScript: SerialWireDebugScript, Script {
    
    func aw_mlcd_initialize() throws {
        let _ = try run(getFunction(name: "aw_mlcd_initialize").address)
    }
    
    func aw_mlcd_test_pattern() throws {
        let _ = try run(getFunction(name: "aw_mlcd_test_pattern").address)
    }
    
    func aw_mlcd_update_image() throws {
        let _ = try run(getFunction(name: "aw_mlcd_update_image").address)
    }
    
    override func setup() throws {
        try super.setup()
        try setupExecutable(resource: "Display", address: 0x10000000, length: 0x40000)
    }
    
    func main() throws {
        try setup()
        
        let powerSetupScript = PowerSetupScript(fixture: fixture, presenter: presenter, serialWireInstrumentIdentifier: "SerialWire1")
        try powerSetupScript.setup()
        
        presenter.show(message: "This script assumes a previous script has setup the 3.2 V and 5.0 V rails.")

        let _ = try run(getFunction(name: "aw_mlcd_set_status").address, r0: 64)
        var status = try run(getFunction(name: "aw_mlcd_get_status").address)
        presenter.show(message: "status \(status)")

        presenter.show(message: "aw_mlcd_initialize")
        try aw_mlcd_initialize()
        status = try run(getFunction(name: "aw_mlcd_get_status").address)
        presenter.show(message: "status \(status)")

        presenter.show(message: "aw_mlcd_test_pattern")
        try aw_mlcd_test_pattern()
        status = try run(getFunction(name: "aw_mlcd_get_status").address)
        presenter.show(message: "status \(status)")

        for _ in 0 ..< 10 {
            presenter.show(message: "aw_mlcd_update_image")
            try aw_mlcd_update_image()
            status = try run(getFunction(name: "aw_mlcd_get_status").address)
            presenter.show(message: "status \(status)")
            let conversion = try fixture.voltageInstrument?.convert()
            presenter.show(message: "voltage = \(String(describing: conversion?.voltage))")
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
    
}
