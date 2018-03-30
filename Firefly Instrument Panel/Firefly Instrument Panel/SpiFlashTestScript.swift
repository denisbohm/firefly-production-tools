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
        
        presenter.show(message: "setting system voltage...")
        let result = try fd_bq25120_set_system_voltage(device: device, voltage: 3.2)
        Thread.sleep(forTimeInterval: 0.1)
        let conversion = try fixture.voltageInstrument?.convert()
        presenter.show(message: "result = \(result), voltage = \(String(describing: conversion?.voltage))")
    }

    override func setup() throws {
        try super.setup()
        try setupExecutable(resource: "firefly_test_suite")
        let _ = try run(getFunction(name: "SystemInit").address)
        try setupSystemVoltage()
    }
    
    class fd_spim_bus_t: Heap.Struct {
        
        let instance: Heap.Primitive<UInt32>
        let sclk: fd_gpio_t
        let mosi: fd_gpio_t
        let miso: fd_gpio_t
        let frequency: Heap.Primitive<UInt32>
        let mode: Heap.Primitive<UInt32>
        
        init(instance: UInt32, sclk: fd_gpio_t, mosi: fd_gpio_t, miso: fd_gpio_t, frequency: UInt32, mode: UInt32) {
            self.instance = Heap.Primitive<UInt32>(value: instance)
            self.sclk = sclk
            self.mosi = mosi
            self.miso = miso
            self.frequency = Heap.Primitive<UInt32>(value: frequency)
            self.mode = Heap.Primitive<UInt32>(value: mode)
            super.init(fields: [self.instance, self.sclk, self.mosi, self.miso, self.frequency, self.mode])
        }
        
    }
    
    class fd_spim_device_t: Heap.Struct {
        
        let bus: Heap.Reference<fd_spim_bus_t>
        let csn: fd_gpio_t
        
        init(bus: fd_spim_bus_t, csn: fd_gpio_t) {
            self.bus = Heap.Reference(object: bus)
            self.csn = csn
            super.init(fields: [self.bus, self.csn])
        }
        
    }
    
    func fd_spim_initialize(heap: Heap) throws -> (flashDevice: fd_spim_device_t, lsm6dslDevice: fd_spim_device_t) {
        let SPIM1: UInt32 = 0x40004000
        let SPIM2: UInt32 = 0x40023000
        let flashBus = fd_spim_bus_t(
            instance: SPIM1,
            sclk: fd_gpio_t(port: 0, pin: 5),
            mosi: fd_gpio_t(port: 0, pin: 4),
            miso: fd_gpio_t(port: 0, pin: 7),
            frequency: 8000000,
            mode: 3
        )
        let lsm6dslBus = fd_spim_bus_t(
            instance: SPIM2,
            sclk: fd_gpio_t(port: 1, pin: 3),
            mosi: fd_gpio_t(port: 1, pin: 2),
            miso: fd_gpio_t(port: 1, pin: 1),
            frequency: 8000000,
            mode: 3
        )
        let busCount: UInt32 = 2
        
        let flashDevice = fd_spim_device_t(bus: flashBus, csn: fd_gpio_t(port: 0, pin: 6))
        let lsm6dslDevice = fd_spim_device_t(bus: lsm6dslBus, csn: fd_gpio_t(port: 1, pin: 4))
        let deviceCount: UInt32 = 2
        
        heap.addRoot(object: flashBus)
        heap.addRoot(object: lsm6dslBus)
        heap.addRoot(object: flashDevice)
        heap.addRoot(object: lsm6dslDevice)

        heap.locate()
        heap.encode()
        try serialWireDebug?.writeMemory(heap.baseAddress, data: heap.data)
        let _ = try run(getFunction(name: "fd_spim_initialize").address, r0: flashBus.heapAddress!, r1: busCount, r2: flashDevice.heapAddress!, r3: deviceCount)
        return (flashDevice: flashDevice, lsm6dslDevice: lsm6dslDevice)
    }
    
    func fd_spim_bus_enable(bus: fd_spim_bus_t) throws {
        let _ = try run(getFunction(name: "fd_spim_bus_enable").address, r0: bus.heapAddress!)
    }
    
    class fd_spi_flash_information_t: Heap.Struct {
        
        let manufacturer_id: Heap.Primitive<UInt8>
        let device_id: Heap.Primitive<UInt8>
        let memory_type: Heap.Primitive<UInt8>
        let memory_capacity: Heap.Primitive<UInt8>
        
        init(manufacturer_id: UInt8, device_id: UInt8, memory_type: UInt8, memory_capacity: UInt8) {
            self.manufacturer_id = Heap.Primitive(value: manufacturer_id)
            self.device_id = Heap.Primitive(value: device_id)
            self.memory_type = Heap.Primitive(value: memory_type)
            self.memory_capacity = Heap.Primitive(value: memory_capacity)
            super.init(fields: [self.manufacturer_id, self.device_id, self.memory_type, self.memory_capacity])
        }
        
    }
    
    func fd_spi_flash_get_information(heap: Heap, device: fd_spim_device_t) throws -> fd_spi_flash_information_t {
        let subheap = Heap()
        subheap.setBase(address: heap.freeAddress)
        let information = fd_spi_flash_information_t(manufacturer_id: 0, device_id: 0, memory_type: 0, memory_capacity: 0)
        subheap.addRoot(object: information)
        subheap.locate()
        subheap.encode()
        let _ = try run(getFunction(name: "fd_spi_flash_get_information").address, r0: device.heapAddress!, r1: information.heapAddress!)
        subheap.data = try serialWireDebug!.readMemory(subheap.baseAddress, length: UInt32(subheap.data.count))
        try subheap.decode()
        return information
    }
    
    class fd_lsm6dsl_configuration_t: Heap.Struct {
        
        let fifo_threshold: Heap.Primitive<UInt16>
        let fifo_output_data_rate: Heap.Primitive<UInt8>
        let accelerometer_output_data_rate: Heap.Primitive<UInt8>
        let accelerometer_low_power: Heap.Primitive<Bool>
        let accelerometer_full_scale_range: Heap.Primitive<UInt8>
        let accelerometer_bandwidth_filter: Heap.Primitive<UInt8>
        let accelerometer_enable: Heap.Primitive<Bool>
        let gyro_output_data_rate: Heap.Primitive<UInt8>
        let gyro_low_power: Heap.Primitive<Bool>
        let gyro_full_scale_range: Heap.Primitive<UInt8>
        let gyro_high_pass_filter: Heap.Primitive<UInt8>
        let gyro_enable: Heap.Primitive<Bool>

        init(
            fifo_threshold: UInt16,
            fifo_output_data_rate: UInt8,
            accelerometer_output_data_rate: UInt8,
            accelerometer_low_power: Bool,
            accelerometer_full_scale_range: UInt8,
            accelerometer_bandwidth_filter: UInt8,
            accelerometer_enable: Bool,
            gyro_output_data_rate: UInt8,
            gyro_low_power: Bool,
            gyro_full_scale_range: UInt8,
            gyro_high_pass_filter: UInt8,
            gyro_enable: Bool
        ) {
            self.fifo_threshold = Heap.Primitive(value: fifo_threshold)
            self.fifo_output_data_rate = Heap.Primitive(value: fifo_output_data_rate)
            self.accelerometer_output_data_rate = Heap.Primitive(value: accelerometer_output_data_rate)
            self.accelerometer_low_power = Heap.Primitive(value: accelerometer_low_power)
            self.accelerometer_full_scale_range = Heap.Primitive(value: accelerometer_full_scale_range)
            self.accelerometer_bandwidth_filter = Heap.Primitive(value: accelerometer_bandwidth_filter)
            self.accelerometer_enable = Heap.Primitive(value: accelerometer_enable)
            self.gyro_output_data_rate = Heap.Primitive(value: gyro_output_data_rate)
            self.gyro_low_power = Heap.Primitive(value: gyro_low_power)
            self.gyro_full_scale_range = Heap.Primitive(value: gyro_full_scale_range)
            self.gyro_high_pass_filter = Heap.Primitive(value: gyro_high_pass_filter)
            self.gyro_enable = Heap.Primitive(value: gyro_enable)
            super.init(fields: [
                self.fifo_threshold,
                self.fifo_output_data_rate,
                self.accelerometer_output_data_rate,
                self.accelerometer_low_power,
                self.accelerometer_full_scale_range,
                self.accelerometer_bandwidth_filter,
                self.accelerometer_enable,
                self.gyro_output_data_rate,
                self.gyro_low_power,
                self.gyro_full_scale_range,
                self.gyro_high_pass_filter,
                self.gyro_enable
            ])
        }
        
    }
    
    class fd_lsm6dsl_accelerometer_sample_t: Heap.Struct {
        
        let x: Heap.Primitive<Int16>
        let y: Heap.Primitive<Int16>
        let z: Heap.Primitive<Int16>
        
        init(x: Int16, y: Int16, z: Int16) {
            self.x = Heap.Primitive(value: x)
            self.y = Heap.Primitive(value: y)
            self.z = Heap.Primitive(value: z)
            super.init(fields: [self.x, self.y, self.z])
        }
        
    }
    
    class fd_lsm6dsl_gyro_sample_t: Heap.Struct {
        
        let x: Heap.Primitive<Int16>
        let y: Heap.Primitive<Int16>
        let z: Heap.Primitive<Int16>
        
        init(x: Int16, y: Int16, z: Int16) {
            self.x = Heap.Primitive(value: x)
            self.y = Heap.Primitive(value: y)
            self.z = Heap.Primitive(value: z)
            super.init(fields: [self.x, self.y, self.z])
        }
        
    }
    
    class fd_lsm6dsl_sample_t: Heap.Struct {
        
        let accelerometer: fd_lsm6dsl_accelerometer_sample_t
        let gyro: fd_lsm6dsl_gyro_sample_t
        
        init(accelerometer: fd_lsm6dsl_accelerometer_sample_t, gyro: fd_lsm6dsl_gyro_sample_t) {
            self.accelerometer = accelerometer
            self.gyro = gyro
            super.init(fields: [self.accelerometer, self.gyro])
        }
        
    }
    
    func fd_lsm6dsl_read(device: fd_spim_device_t, location: UInt8) throws -> UInt8 {
        let resultR0 = try run(getFunction(name: "fd_lsm6dsl_read").address, r0: device.heapAddress!, r1: UInt32(location))
        return UInt8(truncatingIfNeeded: resultR0)
    }
    
    func fd_lsm6ds3_configure(device: fd_spim_device_t, configuration: fd_lsm6dsl_configuration_t) throws {
        let _ = try run(getFunction(name: "fd_lsm6ds3_configure").address, r0: device.heapAddress!, r1: configuration.heapAddress!)
    }
    
    func fd_lsm6dsl_read_fifo_samples(device: fd_spim_device_t, samples: fd_lsm6dsl_sample_t, sample_count: UInt32) throws -> Int {
        let resultR0 = try run(getFunction(name: "fd_lsm6dsl_read_fifo_samples").address, r0: device.heapAddress!, r1: samples.heapAddress!, r2: sample_count)
        return Int(resultR0)
    }
    
    let FD_LSM6DSL_ODR_POWER_DOWN = UInt8(0b0000)
    let FD_LSM6DSL_ODR_13_HZ      = UInt8(0b0001)
    let FD_LSM6DSL_ODR_26_HZ      = UInt8(0b0010)
    let FD_LSM6DSL_ODR_52_HZ      = UInt8(0b0011)
    let FD_LSM6DSL_ODR_104_HZ     = UInt8(0b0100)
    let FD_LSM6DSL_ODR_208_HZ     = UInt8(0b0101)
    let FD_LSM6DSL_ODR_416_HZ     = UInt8(0b0110)
    let FD_LSM6DSL_ODR_833_HZ     = UInt8(0b0111)
    let FD_LSM6DSL_ODR_1660_HZ    = UInt8(0b1000)
    let FD_LSM6DSL_ODR_3330_HZ    = UInt8(0b1001)
    let FD_LSM6DSL_ODR_6660_HZ    = UInt8(0b1010)
    
    let FD_LSM6DSL_XFS_2_G  = UInt8(0b00)
    let FD_LSM6DSL_XFS_4_G  = UInt8(0b10)
    let FD_LSM6DSL_XFS_8_G  = UInt8(0b11)
    let FD_LSM6DSL_XFS_16_G = UInt8(0b01)
    
    let FD_LSM6DSL_XBWF_50_HZ  = UInt8(0b11)
    let FD_LSM6DSL_XBWF_100_HZ = UInt8(0b10)
    let FD_LSM6DSL_XBWF_200_HZ = UInt8(0b01)
    let FD_LSM6DSL_XBWF_400_HZ = UInt8(0b00)
    
    let FD_LSM6DSL_GFS_125_DPS  = UInt8(0b001)
    let FD_LSM6DSL_GFS_245_DPS  = UInt8(0b000)
    let FD_LSM6DSL_GFS_500_DPS  = UInt8(0b010)
    let FD_LSM6DSL_GFS_1000_DPS = UInt8(0b100)
    let FD_LSM6DSL_GFS_2000_DPS = UInt8(0b110)
    
    let FD_LSM6DSL_GHPF_DISABLED_HZ = UInt8(0b000)
    let FD_LSM6DSL_GHPF_P0081_HZ    = UInt8(0b100)
    let FD_LSM6DSL_GHPF_P0324_HZ    = UInt8(0b101)
    let FD_LSM6DSL_GHPF_2P07_HZ     = UInt8(0b110)
    let FD_LSM6DSL_GHPF_16P32_HZ    = UInt8(0b111)

    func lsm6dslTest(heap: Heap, device: fd_spim_device_t) throws {
        try fd_spim_bus_enable(bus: device.bus.object)

        let whoAmI = try fd_lsm6dsl_read(device: device, location: 0x0f)
        presenter.show(message: String(format: "lsm6dsl whoAmI %02x", whoAmI))
        
        try dumpP0()
        try dumpP1()
        try dumpSPIM2()
        
        let subheap = Heap()
        subheap.setBase(address: (heap.freeAddress + 3) & ~0x3)
        let configuration = fd_lsm6dsl_configuration_t(
            fifo_threshold: 32,
            fifo_output_data_rate: FD_LSM6DSL_ODR_13_HZ,
            accelerometer_output_data_rate: FD_LSM6DSL_ODR_13_HZ,
            accelerometer_low_power: true,
            accelerometer_full_scale_range: FD_LSM6DSL_XFS_2_G,
            accelerometer_bandwidth_filter: FD_LSM6DSL_XBWF_50_HZ,
            accelerometer_enable: true,
            gyro_output_data_rate: FD_LSM6DSL_ODR_13_HZ,
            gyro_low_power: true,
            gyro_full_scale_range: FD_LSM6DSL_GFS_125_DPS,
            gyro_high_pass_filter: FD_LSM6DSL_GHPF_DISABLED_HZ,
            gyro_enable: true
        )
        subheap.addRoot(object: configuration)
        let sample = fd_lsm6dsl_sample_t(
            accelerometer: fd_lsm6dsl_accelerometer_sample_t(x: 0, y: 0, z: 0),
            gyro: fd_lsm6dsl_gyro_sample_t(x: 0, y: 0, z: 0)
        )
        subheap.addRoot(object: sample)
        subheap.locate()
        subheap.encode()
        while (subheap.data.count & 0x3) != 0 {
            subheap.data.append(0)
        }
        try serialWireDebug?.writeMemory(subheap.baseAddress, data: subheap.data)
        try fd_lsm6ds3_configure(device: device, configuration: configuration)
        Thread.sleep(forTimeInterval: 1.0)
        let count = try fd_lsm6dsl_read_fifo_samples(device: device, samples: sample, sample_count: 1)
        subheap.data = try serialWireDebug!.readMemory(subheap.baseAddress, length: UInt32(subheap.data.count))
        try subheap.decode()
        presenter.show(message: String(format: "n=\(count) ax=%d, ay=%d, az=%d, gx=%d, gy=%d, gz=%d",
            sample.accelerometer.x.value,
            sample.accelerometer.y.value,
            sample.accelerometer.z.value,
            sample.gyro.x.value,
            sample.gyro.y.value,
            sample.gyro.z.value
        ))
    }

    func main() throws {
        try setup()

        let heap = Heap()
        heap.setBase(address: cortex.heapRange.location)
        presenter.show(message: "initializing SPIM...")
        let (flashDevice, lsm6dslDevice) = try fd_spim_initialize(heap: heap)
        presenter.show(message: "enabling SPIM bus...")
        try fd_spim_bus_enable(bus: flashDevice.bus.object)
        presenter.show(message: "getting SPI flash information...")
        let information = try fd_spi_flash_get_information(heap: heap, device: flashDevice)
        presenter.show(message: String(format: "%02x %02x %02x %02x", information.manufacturer_id.value, information.device_id.value, information.memory_type.value, information.memory_capacity.value))
        presenter.show(message: "getting LSM6DSL samples...")
        try lsm6dslTest(heap: heap, device: lsm6dslDevice)
    }

}
