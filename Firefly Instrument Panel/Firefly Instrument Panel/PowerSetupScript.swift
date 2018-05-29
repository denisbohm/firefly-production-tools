//
//  PowerSetupScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/1/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments

class PowerSetupScript: SerialWireDebugScript {
    
    class fd_gpio_t: Heap.Struct {
        
        var port: Heap.Primitive<UInt32>
        var pin: Heap.Primitive<UInt32>
        
        init(port: UInt32, pin: UInt32) {
            self.port = Heap.Primitive<UInt32>(value: port)
            self.pin = Heap.Primitive<UInt32>(value: pin)
            super.init(fields: [self.port, self.pin])
        }
        
    }
    
    func fd_gpio_configure_output(gpio: fd_gpio_t) throws {
        let _ = try run(getFunction(name: "fd_gpio_configure_output").address, r0: gpio.port.value, r1: gpio.pin.value)
    }
    
    func fd_gpio_configure_output_open_drain(gpio: fd_gpio_t) throws {
        let _ = try run(getFunction(name: "fd_gpio_configure_output_open_drain").address, r0: gpio.port.value, r1: gpio.pin.value)
    }
    
    func fd_gpio_set(gpio: fd_gpio_t, value: Bool) throws {
        let _ = try run(getFunction(name: "fd_gpio_set").address, r0: gpio.port.value, r1: gpio.pin.value, r2: value ? 1 : 0)
    }
    
    class fd_i2cm_bus_t: Heap.Struct {
        
        let instance: Heap.Primitive<UInt32>
        let scl: fd_gpio_t
        let sda: fd_gpio_t
        let frequency: Heap.Primitive<UInt32>
        
        init(instance: UInt32, scl: fd_gpio_t, sda: fd_gpio_t, frequency: UInt32) {
            self.instance = Heap.Primitive(value: instance)
            self.scl = scl
            self.sda = sda
            self.frequency = Heap.Primitive(value: frequency)
            super.init(fields: [self.instance, self.scl, self.sda, self.frequency])
        }
        
    }
    
    class fd_i2cm_device_t: Heap.Struct {
        
        let bus: Heap.Reference<fd_i2cm_bus_t>
        let address: Heap.Primitive<UInt32>
        
        init(bus: fd_i2cm_bus_t, address: UInt32) {
            self.bus = Heap.Reference(object: bus)
            self.address = Heap.Primitive(value: address)
            super.init(fields: [self.bus, self.address])
        }
        
    }
    
    func fd_i2cm_initialize(heap: Heap) throws -> (bus: fd_i2cm_bus_t, device: fd_i2cm_device_t) {
        let TWIM0: UInt32 = 0x40003000
        let scl = fd_gpio_t(port: 1, pin: 12)
        let sda = fd_gpio_t(port: 1, pin: 13)
        let bus = fd_i2cm_bus_t(instance: TWIM0, scl: scl, sda: sda, frequency: 100000)
        heap.addRoot(object: bus)
        let busCount: UInt32 = 1
        
        let address: UInt32 = 0x6a // bq25120 7-bit address
        let device = fd_i2cm_device_t(bus: bus, address: address)
        heap.addRoot(object: device)
        let deviceCount: UInt32 = 1
        
        heap.locate()
        heap.encode()
        try serialWireDebug?.writeMemory(heap.baseAddress, data: heap.data)
        let _ = try run(getFunction(name: "fd_i2cm_initialize").address, r0: bus.heapAddress!, r1: busCount, r2: device.heapAddress!, r3: deviceCount)
        return (bus: bus, device: device)
    }
    
    func fd_i2cm_bus_enable(bus: fd_i2cm_bus_t) throws {
        let _ = try run(getFunction(name: "fd_i2cm_bus_enable").address, r0: bus.heapAddress!)
    }
    
    func fd_bq25120_set_system_voltage(device: fd_i2cm_device_t, voltage: Float) throws -> Bool {
        let cdn = fd_gpio_t(port: 1, pin: 15)
        try fd_gpio_configure_output(gpio: cdn)
        try fd_gpio_set(gpio: cdn, value: true)
        try serialWireDebug?.writeRegister(UInt16(CORTEX_M_REGISTER_S0), value:voltage.bitPattern)
        let resultR0 = try run(getFunction(name: "fd_bq25120_set_system_voltage").address, r0: device.heapAddress!)
        return resultR0 != 0
    }
    
    func setupSystemVoltage() throws {
        let heap = Heap()
        heap.setBase(address: cortex.heapRange.location)
        
        presenter.show(message: "initializing I2CM...")
        let (bus, device) = try fd_i2cm_initialize(heap: heap)
        
        presenter.show(message: "enabling I2C bus...")
        try fd_i2cm_bus_enable(bus: bus)
        
        presenter.show(message: "setting system rail to 3.2 V...")
        let result = try fd_bq25120_set_system_voltage(device: device, voltage: 3.2)
        Thread.sleep(forTimeInterval: 0.1)
        let conversion = try fixture.voltageInstrument?.convert()
        presenter.show(message: "result = \(result), voltage = \(String(describing: conversion?.voltage))")
        
        presenter.show(message: "enabling 5 V rail...")
        let boost_5v0_en = fd_gpio_t(port: 0, pin: 8)
        try fd_gpio_configure_output(gpio: boost_5v0_en)
        try fd_gpio_set(gpio: boost_5v0_en, value: true)
        Thread.sleep(forTimeInterval: 0.1)
        // !!! VB is not connected on instrument board, so can't test 5V rail... -denis
        //        let conversion5V = try fixture.auxiliaryVoltageInstrument?.convert()
        //        presenter.show(message: "result = \(result), voltage = \(String(describing: conversion5V?.voltage))")
    }
    
    override func setup() throws {
        serialWireInstrument = fixture.getSerialWireInstrument(serialWireInstrumentIdentifier)
        try setupSerialWireDebug()

        try setupExecutable(resource: "fd_test_suite_nrf5", address: 0x20000000, length: 0x40000)
        let _ = try run(getFunction(name: "SystemInit").address)
        try setupSystemVoltage()
    }
    
}
