//
//  SpiFlashTestScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments

class SpiFlashTestScript: SerialWireDebugScript, Script {

    struct fd_gpio_t {
        let port: UInt32
        let pin: UInt32
    }
    
    struct fd_spi_flash_information_t {
        let manufacturer_id: UInt8
        let device_id: UInt8
        let memory_type: UInt8
        let memory_capacity: UInt8
    }
    
    override func setup() throws {
        try super.setup()
        try setupExecutable(resource: "firefly_test_suite")
    }
    
    func newSpimBus(binary: Binary, instance: UInt32, sclk: fd_gpio_t, mosi: fd_gpio_t, miso: fd_gpio_t, frequency: UInt32, mode: UInt32) -> UInt32 {
        let location = cortex.heapRange.location
        binary.write(instance)
        binary.write(sclk.port)
        binary.write(sclk.pin)
        binary.write(mosi.port)
        binary.write(mosi.pin)
        binary.write(miso.port)
        binary.write(miso.pin)
        binary.write(frequency)
        binary.write(mode)
        return location
    }
    
    func newSpimDevice(binary: Binary, bus: UInt32, csn: fd_gpio_t) -> UInt32 {
        let location = cortex.heapRange.location + UInt32(binary.length)
        binary.write(bus)
        binary.write(csn.port)
        binary.write(csn.pin)
        return location
    }
    
    func fd_spim_initialize(binary: Binary) throws -> (bus: UInt32, device: UInt32) {
        let SPIM0: UInt32 = 0x40003000
        let sclk = fd_gpio_t(port: 0, pin: 5)
        let mosi = fd_gpio_t(port: 0, pin: 4)
        let miso = fd_gpio_t(port: 0, pin: 7)
        let bus = newSpimBus(binary: binary, instance: SPIM0, sclk: sclk, mosi: mosi, miso: miso, frequency: 8000000, mode: 3)
        let busCount: UInt32 = 1
        let csn = fd_gpio_t(port: 0, pin: 6)
        let device = newSpimDevice(binary: binary, bus: bus, csn: csn)
        let deviceCount: UInt32 = 1
        try serialWireDebug?.writeMemory(cortex.heapRange.location, data: binary.data)
        try cortex.run(getFunction(name: "fd_spim_initialize").address, r0: bus, r1: busCount, r2: device, r3: deviceCount, timeout: 1.0)
        return (bus: bus, device: device)
    }
    
    func fd_spim_bus_enable(binary: Binary, bus: UInt32) throws {
        try cortex.run(getFunction(name: "fd_spim_bus_enable").address, r0: bus, timeout: 1.0)
    }
    
    func fd_spi_flash_get_information(binary: Binary, device: UInt32) throws -> fd_spi_flash_information_t {
        let information = cortex.heapRange.location + UInt32(binary.length)
        try cortex.run(getFunction(name: "fd_spi_flash_get_information").address, r0: device, r1: information, timeout: 1.0)
        let data = try serialWireDebug!.readMemory(information, length: 4)
        return fd_spi_flash_information_t(manufacturer_id: data[0], device_id: data[1], memory_type: data[2], memory_capacity: data[3])
    }

    func main() throws {
        try setup()

        let binary = Binary(byteOrder: .littleEndian)
        presenter.show(message: "initializing SPIM...")
        let (bus, device) = try fd_spim_initialize(binary: binary)
        presenter.show(message: "enabling SPIM bus...")
        try fd_spim_bus_enable(binary: binary, bus: bus)
        presenter.show(message: "getting SPI flash information...")
        let information = try fd_spi_flash_get_information(binary: binary, device: device)
        presenter.show(message: String(format: "%02x %02x %02x %02x", information.manufacturer_id, information.device_id, information.memory_type, information.memory_capacity))
    }

}
