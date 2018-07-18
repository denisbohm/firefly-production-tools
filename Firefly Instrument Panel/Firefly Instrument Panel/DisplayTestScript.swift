//
//  DisplayTestScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/1/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments

class DisplayTestScript: FireflyDesignScript, Script {
    
    func aw_mlcd_set_status(mlcd: UInt32, status: UInt32) throws {
        let _ = try run(getFunction(name: "aw_mlcd_set_status").address, r0: mlcd, r1: status)
    }
    
    func aw_mlcd_get_status(mlcd: UInt32) throws -> UInt32 {
        return try run(getFunction(name: "aw_mlcd_get_status").address, r0: mlcd)
    }
    
    func aw_mlcd_initialize(mlcd: UInt32) throws {
        let _ = try run(getFunction(name: "aw_mlcd_initialize").address, r0: mlcd)
    }
    
    func aw_mlcd_test_pattern(mlcd: UInt32) throws {
        let _ = try run(getFunction(name: "aw_mlcd_test_pattern").address, r0: mlcd)
    }
    
    func aw_mlcd_update_image(mlcd: UInt32) throws {
        let _ = try run(getFunction(name: "aw_mlcd_update_image").address, r0: mlcd)
    }
    
    override func setup() throws {
        try super.setup()
        
        // bring up 3.2 V rail and 5 V rail (via nRF)
        let powerSetupScript = PowerSetupScript(fixture: fixture, presenter: presenter, serialWireInstrumentIdentifier: "SerialWire1")
        try powerSetupScript.setup()
        
        try setupExecutable(resource: "aw_test_suite_apollo", address: 0x10000000, length: 0x40000)
    }
    
    class fd_pwm_module_t: Heap.Struct {
        
        let instance: Heap.Primitive<UInt32>
        let frequency: Heap.Primitive<Float32>
        
        init(instance: UInt32, frequency: Float32) {
            self.instance = Heap.Primitive(value: instance)
            self.frequency = Heap.Primitive(value: frequency)
            super.init(fields: [self.instance, self.frequency])
        }
        
    }
    
    class fd_pwm_channel_t: Heap.Struct {
        
        let module: Heap.Reference<fd_pwm_module_t>
        let instance: Heap.Primitive<UInt32>
        let gpio: fd_gpio_t

        init(module: fd_pwm_module_t, instance: UInt32, gpio: fd_gpio_t) {
            self.module = Heap.Reference(object: module)
            self.instance = Heap.Primitive(value: instance)
            self.gpio = gpio
            super.init(fields: [self.module, self.instance, self.gpio])
        }
        
    }
    
    func main() throws {
        try setup()
        
        let backlight = fd_gpio_t(port: 0, pin: 5)
        try fd_gpio_configure_output(gpio: backlight);
        try fd_gpio_set(gpio: backlight, value: true);
        Thread.sleep(forTimeInterval: 1.0)
        try fd_gpio_set(gpio: backlight, value: false);

        let heap = Heap()
        heap.setBase(address: cortex.heapRange.location)
        let statusField = Heap.PrimitiveStruct<UInt32>(value: 0)
        heap.addRoot(object: statusField)
        let module = fd_pwm_module_t(instance: 3, frequency: 50.0)
        heap.addRoot(object: module)
        let channelVA = fd_pwm_channel_t(module: module, instance: 0, gpio: fd_gpio_t(port: 0, pin: 48))
        heap.addRoot(object: channelVA)
        let channelVCOM = fd_pwm_channel_t(module: module, instance: 1, gpio: fd_gpio_t(port: 0, pin: 23))
        heap.addRoot(object: channelVCOM)
        let imageField = Heap.PrimitiveStruct<UInt32>(value: 0x10000000 + 0x40000 - 240 * 240)
        heap.addRoot(object: imageField)
        heap.locate()
        heap.encode()
        try serialWireDebug?.writeMemory(heap.baseAddress, data: heap.data)
        let mlcd = statusField.heapAddress!
        
        try aw_mlcd_set_status(mlcd: mlcd, status: 64)
        var status = try aw_mlcd_get_status(mlcd: mlcd)
        presenter.show(message: "status \(status)")

        presenter.show(message: "aw_mlcd_initialize")
        try aw_mlcd_initialize(mlcd: mlcd)
        status = try aw_mlcd_get_status(mlcd: mlcd)
        presenter.show(message: "status \(status)")

        presenter.show(message: "aw_mlcd_test_pattern")
        try aw_mlcd_test_pattern(mlcd: mlcd)
        status = try aw_mlcd_get_status(mlcd: mlcd)
        presenter.show(message: "status \(status)")

        try fixture.voltageSenseRelayInstrument?.set(true)
        for _ in 0 ..< 100000 {
            presenter.show(message: "aw_mlcd_update_image")
            try aw_mlcd_update_image(mlcd: mlcd)
            status = try aw_mlcd_get_status(mlcd: mlcd)
            presenter.show(message: "status \(status)")
            let conversion = try fixture.voltageInstrument?.convert()
            presenter.show(message: "voltage = \(String(describing: conversion?.voltage))")
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
    
}
