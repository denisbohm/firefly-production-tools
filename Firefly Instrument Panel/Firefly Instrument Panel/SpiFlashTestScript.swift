//
//  SpiFlashTestScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments

class FireflyDesignScript: SerialWireDebugScript {
    
    var setupState: (heap: Heap, bus: fd_i2cm_bus_t, device: fd_i2cm_device_t)? = nil
    
    class fd_gpio_t: Heap.Struct {
        
        var port: Heap.Primitive<UInt32>
        var pin: Heap.Primitive<UInt32>
        
        init(port: UInt32, pin: UInt32) {
            self.port = Heap.Primitive<UInt32>(value: port)
            self.pin = Heap.Primitive<UInt32>(value: pin)
            super.init(fields: [self.port, self.pin])
        }
        
    }
    
    func fd_gpio_configure_input_pull_up(gpio: fd_gpio_t) throws {
        let _ = try run(getFunction(name: "fd_gpio_configure_input_pull_up").address, r0: gpio.port.value, r1: gpio.pin.value)
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
    
    func fd_gpio_get(gpio: fd_gpio_t) throws -> Bool {
        let r0 = try run(getFunction(name: "fd_gpio_get").address, r0: gpio.port.value, r1: gpio.pin.value)
        return r0 != 0
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
    
    func fd_bq25120_write(heap: Heap, device: fd_i2cm_device_t, location: UInt8, value: UInt8) throws -> Bool {
        let resultR0 = try run(getFunction(name: "fd_bq25120_write").address, r0: device.heapAddress!, r1: UInt32(location), r2: UInt32(value))
        return resultR0 != 0
    }
    
    func fd_bq25120_read(heap: Heap, device: fd_i2cm_device_t, location: UInt8) throws -> (result: Bool, value: UInt8) {
        try serialWireDebug?.writeMemory(heap.freeAddress, value: 0x5a5a5a5a)
        let resultR0 = try run(getFunction(name: "fd_i2cm_device_sequence_tx1_rx1").address, r0: device.heapAddress!, r1: UInt32(location), r2: heap.freeAddress)
        let data = try serialWireDebug?.readMemory(heap.freeAddress, length: 1)
        return (result: resultR0 != 0, value: data![0])
    }
    
    func fd_bq25120_set_system_voltage(device: fd_i2cm_device_t, voltage: Float) throws -> Bool {
        try serialWireDebug?.writeRegister(UInt16(CORTEX_M_REGISTER_S0), value:voltage.bitPattern)
        let resultR0 = try run(getFunction(name: "fd_bq25120_set_system_voltage").address, r0: device.heapAddress!)
        return resultR0 != 0
    }
    
    func fd_bq25120_read_battery_voltage(device: fd_i2cm_device_t) throws -> (result: Bool, voltage: Float) {
        #if false
        let resultR0 = try run(getFunction(name: "fd_bq25120_read_battery_voltage").address, r0: device.heapAddress!)
        let result = resultR0 != 0
        if !result {
            return (result: false, voltage: 0.0)
        }
        var voltageBitPattern: UInt32 = 0
        try serialWireDebug?.readRegister(UInt16(CORTEX_M_REGISTER_S0), value: &voltageBitPattern)
        let voltage = Float(bitPattern: voltageBitPattern)
        #endif
        let heap = setupState!.heap
        let (result1, r1) = try fd_bq25120_read(heap: heap, device: device, location: FD_BQ25120_BATT_VOLTAGE_CTL_REG)
        if !result1 {
            return (result: false, voltage: 0.0)
        }
        var battery_regulation_voltage: Float = 3.6 + Float(r1 >> 1) * 0.01
        let result2 = try fd_bq25120_write(heap: heap, device: device, location: FD_BQ25120_BATT_VOLT_MONITOR_REG, value: 0b10000000)
        if !result2 {
            return (result: false, voltage: 0.0)
        }
        Thread.sleep(forTimeInterval: 0.002)
        let (result3, r3) = try fd_bq25120_read(heap: heap, device: device, location: FD_BQ25120_BATT_VOLT_MONITOR_REG)
        if !result3 {
            return (result: false, voltage: 0.0)
        }
        let range: Float = 0.6 + 0.1 * Float((r3 >> 5) & 0b11)
        let threshold: Float
        switch (r3 >> 2) & 0b111 {
        case 0b111:
            threshold = 0.08
        case 0b110:
            threshold = 0.06
        case 0b011:
            threshold = 0.04
        case 0b010:
            threshold = 0.02
        case 0b001:
            threshold = 0.00
        default:
            battery_regulation_voltage = 0.00
            threshold = 0.00
        }
        let voltage: Float = battery_regulation_voltage * (range + threshold)
        return (result: true, voltage: voltage)
    }
    
    let FD_BQ25120_STATUS_SHIPMODE_REG: UInt8 =     0x00
    let FD_BQ25120_FAULTS_FAULTMASKS_REG: UInt8 =   0x01
    let FD_BQ25120_TSCONTROL_STATUS_REG: UInt8 =    0x02
    let FD_BQ25120_FASTCHARGE_CTL_REG: UInt8 =      0x03
    let FD_BQ25120_CHARGETERM_I2CADDR_REG: UInt8 =  0x04
    let FD_BQ25120_BATT_VOLTAGE_CTL_REG: UInt8 =    0x05
    let FD_BQ25120_SYSTEM_VOUT_CTL_REG: UInt8 =     0x06
    let FD_BQ25120_LOADSW_LDO_CTL_REG: UInt8 =      0x07
    let FD_BQ25120_PUSH_BTN_CTL_REG: UInt8 =        0x08
    let FD_BQ25120_ILIMIT_UVLO_CTL_REG: UInt8 =     0x09
    let FD_BQ25120_BATT_VOLT_MONITOR_REG: UInt8 =   0x0A
    let FD_BQ25120_VIN_DPM_TIMER_REG: UInt8 =       0x0B
    
    func setupSystemVoltage() throws -> (heap: Heap, bus: fd_i2cm_bus_t, device: fd_i2cm_device_t) {
        let heap = Heap()
        heap.setBase(address: cortex.heapRange.location)
        
        presenter.show(message: "initializing I2CM...")
        let (bus, device) = try fd_i2cm_initialize(heap: heap)
        
        presenter.show(message: "enabling I2C bus...")
        try fd_i2cm_bus_enable(bus: bus)
        
        // enable BQ communication
        let cdn = fd_gpio_t(port: 1, pin: 15)
        try fd_gpio_configure_output(gpio: cdn)
        try fd_gpio_set(gpio: cdn, value: true)
        Thread.sleep(forTimeInterval: 1.0);
        
        do {
            let (ok, status) = try fd_bq25120_read(heap: heap, device: device, location: FD_BQ25120_STATUS_SHIPMODE_REG)
            presenter.show(message: String(format:"status: \(ok) 0x%02x", status))
        }
        
        presenter.show(message: "setting system rail to 3.2 V...")
        try fixture.voltageSenseRelayInstrument?.set(true)
        let result = try fd_bq25120_set_system_voltage(device: device, voltage: 3.2)
        Thread.sleep(forTimeInterval: 0.5)
        let conversion = try fixture.voltageInstrument?.convert()
        try fixture.voltageSenseRelayInstrument?.set(false)
        presenter.show(message: "result = \(result), voltage = \(String(describing: conversion?.voltage))")
        
        do {
            let (ok, status) = try fd_bq25120_read(heap: heap, device: device, location: FD_BQ25120_STATUS_SHIPMODE_REG)
            presenter.show(message: String(format:"status: \(ok) 0x%02x", status))
        }
        do {
            let (ok, vout) = try fd_bq25120_read(heap: heap, device: device, location: FD_BQ25120_SYSTEM_VOUT_CTL_REG)
            presenter.show(message: String(format:"vout: \(ok) 0x%02x (expectation: 0xfc)", vout))
        }
        
        presenter.show(message: "enabling 5 V rail...")
        let boost_5v0_en = fd_gpio_t(port: 0, pin: 8)
        try fd_gpio_configure_output(gpio: boost_5v0_en)
        try fd_gpio_set(gpio: boost_5v0_en, value: true)
        Thread.sleep(forTimeInterval: 0.1)
        // !!! VB is not connected on instrument board, so can't test 5V rail... -denis
        //        let conversion5V = try fixture.auxiliaryVoltageInstrument?.convert()
        //        presenter.show(message: "result = \(result), voltage = \(String(describing: conversion5V?.voltage))")
        
        return (heap: heap, bus: bus, device: device)
    }

    override func setup() throws {
        try super.setup()
        try setupExecutable(resource: "fd_test_suite_nrf5", address: 0x20000000, length: 0x40000)
        let _ = try run(getFunction(name: "SystemInit").address)
        setupState = try setupSystemVoltage()
    }
    
}

class SpiFlashTestScript: FireflyDesignScript, Script {

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
            sclk: fd_gpio_t(port: 0, pin: 15),
            mosi: fd_gpio_t(port: 0, pin: 14),
            miso: fd_gpio_t(port: 0, pin: 13),
            frequency: 8000000,
            mode: 3
        )
        let lsm6dslBus = fd_spim_bus_t(
            instance: SPIM2,
            sclk: fd_gpio_t(port: 1, pin: 3),
            mosi: fd_gpio_t(port: 1, pin: 2),
            miso: fd_gpio_t(port: 1, pin: 5),
            frequency: 8000000,
            mode: 3
        )
        let busCount: UInt32 = 2
        
        let flashDevice = fd_spim_device_t(bus: flashBus, csn: fd_gpio_t(port: 0, pin: 16))
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
    
    func fd_spim_device_sequence_tx1_rx1(device: fd_spim_device_t, tx_byte: UInt8) throws -> UInt8 {
        let resultR0 = try run(getFunction(name: "fd_spim_device_sequence_tx1_rx1").address, r0: device.heapAddress!, r1: UInt32(tx_byte))
        return UInt8(truncatingIfNeeded: resultR0)
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
    
    func dumpLSM6DSL(device: fd_spim_device_t) throws {
        NSLog("LSM6DSL Registers")
        for i in 0 ... 0x7f {
        let value = try fd_spim_device_sequence_tx1_rx1(device: device, tx_byte: UInt8(0x80 | i))
            NSLog("  %02x = %02x", i, value)
        }
    }

    func lsm6dslTest(heap: Heap, device: fd_spim_device_t) throws {
        try fd_spim_bus_enable(bus: device.bus.object)

        let whoAmI = try fd_lsm6dsl_read(device: device, location: 0x0f)
        presenter.show(message: String(format: "lsm6dsl whoAmI %02x", whoAmI))
        
        let subheap = Heap()
        subheap.setBase(address: heap.freeAddress)
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
    
    func fd_pwm_initialize(heap: Heap) throws -> (module: fd_pwm_module_t, channel: fd_pwm_channel_t) {
        let PWM0: UInt32 = 0x4001C000
        let module = fd_pwm_module_t(instance: PWM0, frequency: 32000.0)
        heap.addRoot(object: module)
        let moduleCount: UInt32 = 1
        
        let channel = fd_pwm_channel_t(module: module, instance: 0, gpio: fd_gpio_t(port: 0, pin: 20))
        heap.addRoot(object: channel)

        heap.locate()
        heap.encode()
        try serialWireDebug?.writeMemory(heap.baseAddress, data: heap.data)
        let _ = try run(getFunction(name: "fd_pwm_initialize").address, r0: module.heapAddress!, r1: moduleCount)
        return (module: module, channel: channel)
    }
    
    func fd_pwm_module_enable(module: fd_pwm_module_t) throws {
        let _ = try run(getFunction(name: "fd_pwm_module_enable").address, r0: module.heapAddress!)
    }
    
    func fd_pwm_channel_start(channel: fd_pwm_channel_t, intensity: Float32) throws {
        try serialWireDebug?.writeRegister(UInt16(CORTEX_M_REGISTER_S0), value:intensity.bitPattern)
        let _ = try run(getFunction(name: "fd_pwm_channel_start").address, r0: channel.heapAddress!)
    }
    
    func vibrate() throws {
        let motor = fd_gpio_t(port: 0, pin: 20)
        try fd_gpio_configure_output(gpio: motor)
        for _ in 0 ... 1000000 {
            try fd_gpio_set(gpio: motor, value: false)
            try fd_gpio_set(gpio: motor, value: true)
        }

        let heap = Heap()
        heap.setBase(address: cortex.heapRange.location)
        
        presenter.show(message: "initializing PWM...")
        let (module, channel) = try fd_pwm_initialize(heap: heap)
        
        presenter.show(message: "enabling PWM module...")
        try fd_pwm_module_enable(module: module)
        
        presenter.show(message: "starting PWM channel...")
        try fd_pwm_channel_start(channel: channel, intensity: 0.5)
        
        Thread.sleep(forTimeInterval: 15)
    }
    
    func toggle_off_on(gpio: fd_gpio_t, duration: TimeInterval) throws {
        try fd_gpio_configure_output(gpio: gpio)
        try fd_gpio_set(gpio: gpio, value: false)
        Thread.sleep(forTimeInterval: duration)
        try fd_gpio_set(gpio: gpio, value: true)
    }
    
    func petIndicatorTest() throws {
        let red = fd_gpio_t(port: 0, pin: 21)
        try toggle_off_on(gpio: red, duration: 1.0)
        let green = fd_gpio_t(port: 0, pin: 23)
        try toggle_off_on(gpio: green, duration: 1.0)
        let blue = fd_gpio_t(port: 0, pin: 25)
        try toggle_off_on(gpio: blue, duration: 1.0)
    }
    
    func main() throws {
        try setup()

        try petIndicatorTest()
        
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
        presenter.show(message: "vibrating at 32kHz 50% duty cycle...")
        try vibrate()
    }

}
