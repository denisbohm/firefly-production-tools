//
//  SpiFlashTestScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments


protocol Heapable {
    var heapAddress: UInt32? { get set }
}

protocol BinaryWritable: Heapable {
    func write(binary: Binary)
}

protocol BinaryReadable: Heapable {
    init(binary: Binary) throws
}

class SpiFlashTestScript: SerialWireDebugScript, Script {

    struct fd_gpio_t {
        
        let port: UInt32
        let pin: UInt32
        
        func write(binary: Binary) {
            binary.write(port)
            binary.write(pin)
        }
        
    }
    
    func fd_gpio_configure_output(gpio: fd_gpio_t) throws {
        let _ = try run(getFunction(name: "fd_gpio_configure_output").address, r0: gpio.port, r1: gpio.pin)
    }
    
    func fd_gpio_set(gpio: fd_gpio_t, value: Bool) throws {
        let _ = try run(getFunction(name: "fd_gpio_set").address, r0: gpio.port, r1: gpio.pin, r2: value ? 1 : 0)
    }
    
    class fd_i2cm_bus_t: BinaryWritable {
        
        var heapAddress: UInt32? = nil
        
        let instance: UInt32
        let scl: fd_gpio_t
        let sda: fd_gpio_t
        let frequency: UInt32
        
        init(instance: UInt32, scl: fd_gpio_t, sda: fd_gpio_t, frequency: UInt32) {
            self.instance = instance
            self.scl = scl
            self.sda = sda
            self.frequency = frequency
        }
        
        func write(binary: Binary) {
            binary.write(instance)
            scl.write(binary: binary)
            sda.write(binary: binary)
            binary.write(frequency)
        }

    }
    
    class fd_i2cm_device_t: BinaryWritable {
        
        var heapAddress: UInt32? = nil
        
        let bus: fd_i2cm_bus_t
        let address: UInt32
        
        init(bus: fd_i2cm_bus_t, address: UInt32) {
            self.bus = bus
            self.address = address
        }
        
        func write(binary: Binary) {
            bus.write(binary: binary)
            binary.write(address)
        }
        
    }

    func fd_i2cm_initialize(binary: Binary) throws -> (bus: fd_i2cm_bus_t, device: fd_i2cm_device_t) {
        let TWIM0: UInt32 = 0x40003000
        let scl = fd_gpio_t(port: 1, pin: 12)
        let sda = fd_gpio_t(port: 1, pin: 13)
        let bus = fd_i2cm_bus_t(instance: TWIM0, scl: scl, sda: sda, frequency: 100000)
        bus.heapAddress = cortex.heapRange.location + UInt32(binary.length)
        bus.write(binary: binary)
        let busCount: UInt32 = 1
        
        let address: UInt32 = 0xd4 // bq25120 8-bit shifted address
        let device = fd_i2cm_device_t(bus: bus, address: address)
        device.heapAddress = cortex.heapRange.location + UInt32(binary.length)
        device.write(binary: binary)
        let deviceCount: UInt32 = 1
        
        try serialWireDebug?.writeMemory(cortex.heapRange.location, data: binary.data)
        let _ = try run(getFunction(name: "fd_i2cm_initialize").address, r0: bus.heapAddress!, r1: busCount, r2: device.heapAddress!, r3: deviceCount)
        return (bus: bus, device: device)
    }
    
    func fd_i2cm_bus_enable(binary: Binary, bus: fd_i2cm_bus_t) throws {
        let _ = try run(getFunction(name: "fd_i2cm_bus_enable").address, r0: bus.heapAddress!)
    }
    
    func fd_bq25120_set_system_voltage(device: fd_i2cm_device_t, voltage: Float) throws -> Bool {
        let cdn = fd_gpio_t(port: 1, pin: 15)
        try fd_gpio_configure_output(gpio: cdn)
        try fd_gpio_set(gpio: cdn, value: true)
        let resultR0 = try run(getFunction(name: "fd_bq25120_set_system_voltage").address, r0: device.heapAddress!, r1: voltage.bitPattern)
        return resultR0 != 0
    }
    
    func setupSystemVoltage() throws {
        let binary = Binary(byteOrder: .littleEndian)
        presenter.show(message: "initializing I2CM...")
        let (bus, device) = try fd_i2cm_initialize(binary: binary)
        presenter.show(message: "enabling I2C bus...")
        try fd_i2cm_bus_enable(binary: binary, bus: bus)
        presenter.show(message: "setting system voltage...")
        let result = try fd_bq25120_set_system_voltage(device: device, voltage: 3.2)
        presenter.show(message: "result = \(result)")
    }

    override func setup() throws {
        try super.setup()
        try setupExecutable(resource: "firefly_test_suite")
        try setupSystemVoltage()
    }
    
    class fd_spim_bus_t: BinaryWritable {
        
        var heapAddress: UInt32? = nil
        
        let instance: UInt32
        let sclk: fd_gpio_t
        let mosi: fd_gpio_t
        let miso: fd_gpio_t
        let frequency: UInt32
        let mode: UInt32
        
        init(instance: UInt32, sclk: fd_gpio_t, mosi: fd_gpio_t, miso: fd_gpio_t, frequency: UInt32, mode: UInt32) {
            self.instance = instance
            self.sclk = sclk
            self.mosi = mosi
            self.miso = miso
            self.frequency = frequency
            self.mode = mode
        }
        
        func write(binary: Binary) {
            binary.write(instance)
            sclk.write(binary: binary)
            mosi.write(binary: binary)
            miso.write(binary: binary)
            binary.write(frequency)
            binary.write(mode)
        }
        
    }
    
    class fd_spim_device_t: BinaryWritable {
        
        var heapAddress: UInt32? = nil
        
        let bus: fd_spim_bus_t
        let csn: fd_gpio_t
        
        init(bus: fd_spim_bus_t, csn: fd_gpio_t) {
            self.bus = bus
            self.csn = csn
        }
        
        func write(binary: Binary) {
            binary.write(bus.heapAddress!)
            csn.write(binary: binary)
        }
        
    }
    
    func fd_spim_initialize(binary: Binary) throws -> (bus: fd_spim_bus_t, device: fd_spim_device_t) {
        let SPIM1: UInt32 = 0x40004000
        let sclk = fd_gpio_t(port: 0, pin: 5)
        let mosi = fd_gpio_t(port: 0, pin: 4)
        let miso = fd_gpio_t(port: 0, pin: 7)
        let bus = fd_spim_bus_t(instance: SPIM1, sclk: sclk, mosi: mosi, miso: miso, frequency: 8000000, mode: 3)
        bus.heapAddress = cortex.heapRange.location + UInt32(binary.length)
        bus.write(binary: binary)
        let busCount: UInt32 = 1
        
        let csn = fd_gpio_t(port: 0, pin: 6)
        let device = fd_spim_device_t(bus: bus, csn: csn)
        device.heapAddress = cortex.heapRange.location + UInt32(binary.length)
        device.write(binary: binary)
        let deviceCount: UInt32 = 1
        
        try serialWireDebug?.writeMemory(cortex.heapRange.location, data: binary.data)
        let _ = try run(getFunction(name: "fd_spim_initialize").address, r0: bus.heapAddress!, r1: busCount, r2: device.heapAddress!, r3: deviceCount)
        return (bus: bus, device: device)
    }
    
    func fd_spim_bus_enable(binary: Binary, bus: fd_spim_bus_t) throws {
        let _ = try run(getFunction(name: "fd_spim_bus_enable").address, r0: bus.heapAddress!)
    }
    
    class fd_spi_flash_information_t: BinaryReadable {
        
        var heapAddress: UInt32? = nil
        
        let manufacturer_id: UInt8
        let device_id: UInt8
        let memory_type: UInt8
        let memory_capacity: UInt8
        
        init(manufacturer_id: UInt8, device_id: UInt8, memory_type: UInt8, memory_capacity: UInt8) {
            self.manufacturer_id = manufacturer_id
            self.device_id = device_id
            self.memory_type = memory_type
            self.memory_capacity = memory_capacity
        }
        
        required init(binary: Binary) throws {
            try manufacturer_id = binary.read()
            try device_id = binary.read()
            try memory_type = binary.read()
            try memory_capacity = binary.read()
        }
        
    }
    
    func fd_spi_flash_get_information(binary: Binary, device: fd_spim_device_t) throws -> fd_spi_flash_information_t {
        let information = cortex.heapRange.location + UInt32(binary.length)
        let _ = try run(getFunction(name: "fd_spi_flash_get_information").address, r0: device.heapAddress!, r1: information)
        let data = try serialWireDebug!.readMemory(information, length: 4)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        return try fd_spi_flash_information_t(binary: binary)
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
