//
//  ChargeScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 7/23/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation

class ChargeScript: FireflyDesignScript, Script {
    
    let usbPowerPortPin: fd_gpio_t = fd_gpio_t(port: 1, pin: 10)
    let chargeStatusPortPin: fd_gpio_t = fd_gpio_t(port: 0, pin: 3)
    let chipDisablePortPin: fd_gpio_t = fd_gpio_t(port: 1, pin: 15)
    var prechargeMinBatteryVoltage: Float = 3.0
    var prechargeMaxBatteryVoltage: Float = 3.9
    var prechargeDrainTimeout: Float = 60.0
    var prechargeFillTimeout: Float = 60.0
    var chargeTimeout: Float = 60.0
    var minChargingCurrent: Float = 0.100
    var maxChargingCurrent: Float = 0.400
    var minChargedBatteryVoltage: Float = 4.0
    var maxChargedBatteryVoltage: Float = 4.3
    var maxChargedCurrent: Float = 0.001
    
    func readBatteryVoltage() throws -> Float {
        let device = setupState!.devices["bq25120"]!
        let (_, voltage) = try fd_bq25120_read_battery_voltage(device: device)
        return voltage
    }
    
    func readChargeCurrent() throws -> Float {
        return 0.001
    }
    
    func testCharging() throws {
        try fd_gpio_configure_input_pull_up(gpio: usbPowerPortPin)
        try fd_gpio_configure_input_pull_up(gpio: chargeStatusPortPin)
        try fd_gpio_configure_output(gpio: chipDisablePortPin)

        do {
            let value = try fd_gpio_get(gpio: usbPowerPortPin)
            let expected = false
            let pass = value == expected
            presenter.show(message: String(format: "USB power good pin test: \(pass)"))
        }
        
        #if false
        try fixture.drainSupercapRelayInstrument?.set(false)
        try fixture.fillSupercapRelayInstrument?.set(false)
        try fixture.supercapToBatteryRelayInstrument?.set(false)
        try fixture.simulatorToBatteryRelayInstrument?.set(false)
        #endif
        
        let drainDeadline = Date().addingTimeInterval(TimeInterval(prechargeDrainTimeout))
        while Date() < drainDeadline {
            try fixture.supercapToBatteryRelayInstrument?.set(true)
            Thread.sleep(forTimeInterval: 0.1)
            let batteryCapacitorVoltage = try readBatteryVoltage()
            try fixture.supercapToBatteryRelayInstrument?.set(false)
            if batteryCapacitorVoltage < prechargeMaxBatteryVoltage {
                break
            }
            presenter.show(message: "preparing battery simulator by draining supercap below \(prechargeMaxBatteryVoltage) V... (currently at \(batteryCapacitorVoltage) V)")
            // drain the supercap a bit so it is not in a fully charged state
            try fixture.drainSupercapRelayInstrument?.set(true)
            Thread.sleep(forTimeInterval: 5)
            try fixture.drainSupercapRelayInstrument?.set(false)
        }
        
        let fillDeadline = Date().addingTimeInterval(TimeInterval(prechargeFillTimeout))
        while Date() < fillDeadline {
            try fixture.supercapToBatteryRelayInstrument?.set(true)
            Thread.sleep(forTimeInterval: 0.1)
            let batteryCapacitorVoltage = try readBatteryVoltage()
            try fixture.supercapToBatteryRelayInstrument?.set(false)
            if batteryCapacitorVoltage > prechargeMinBatteryVoltage {
                break
            }
            presenter.show(message: "preparing battery simulator by charging supercap above \(prechargeMinBatteryVoltage) V... (currently at \(batteryCapacitorVoltage) V)")
            // charge the supercap to the nominal battery voltage
            try fixture.batteryInstrument?.setEnabled(true)
            try fixture.batteryInstrument?.setVoltage(4.2)
            try fixture.fillSupercapRelayInstrument?.set(true)
            Thread.sleep(forTimeInterval: 5)
            try fixture.fillSupercapRelayInstrument?.set(false)
        }
        try fixture.batteryInstrument?.setEnabled(false)

        // connect DUT to supercap power
        try fixture.supercapToBatteryRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 0.1)
        // enable BQ current limit at 400 mA
        let device = setupState!.devices["bq25120"]!
        let _ = try fd_bq25120_write(heap: setupState!.heap, device: device, location: FD_BQ25120_ILIMIT_UVLO_CTL_REG, value: 0b00111010)
        // enable BQ charging at 300 mA
        let _ = try fd_bq25120_write(heap: setupState!.heap, device: device, location: FD_BQ25120_FASTCHARGE_CTL_REG, value: 0b11101000)
        // turn off DPM feature (so can charge at lower voltages)
        let _ = try fd_bq25120_write(heap: setupState!.heap, device: device, location: FD_BQ25120_VIN_DPM_TIMER_REG, value: 0b10000010)
        try fd_gpio_set(gpio: chipDisablePortPin, value: false)
        Thread.sleep(forTimeInterval: 1.0)
        do {
            let faults = try fd_bq25120_read(heap: setupState!.heap, device: device, location: FD_BQ25120_FAULTS_FAULTMASKS_REG)
            let faults_after = try fd_bq25120_read(heap: setupState!.heap, device: device, location: FD_BQ25120_FAULTS_FAULTMASKS_REG)
            let ts_status = try fd_bq25120_read(heap: setupState!.heap, device: device, location: FD_BQ25120_TSCONTROL_STATUS_REG)
            let value = try fd_gpio_get(gpio: chargeStatusPortPin)
            let expected = false
            let pass = value == expected
            presenter.show(message: "charge status pin test: \(pass), faults: \(faults) -> \(faults_after), ts status: \(ts_status)")
        }
        do {
            let value = try readChargeCurrent()
            let min: Float = minChargingCurrent
            let max: Float = maxChargingCurrent
            let pass = (min <= value) && (value <= max)
            presenter.show(message: "charge current test: \(pass)")
        }
        var status: Bool = false
        let chargeDeadline = Date().addingTimeInterval(TimeInterval(chargeTimeout))
        while Date() < chargeDeadline {
            try fd_gpio_set(gpio: chipDisablePortPin, value: true)
            Thread.sleep(forTimeInterval: 0.1)
            let status_register = try fd_bq25120_read(heap: setupState!.heap, device: device, location: FD_BQ25120_STATUS_SHIPMODE_REG)
            try fd_gpio_set(gpio: chipDisablePortPin, value: false)
            presenter.show(message: "waiting for battery charge to complete... " + String(format: "0b%08b", status_register.value))
            Thread.sleep(forTimeInterval: 1)
            
            status = try fd_gpio_get(gpio: chargeStatusPortPin)
            if status {
                break
            }
        }
        do {
            let expected = true
            let pass = status == expected
            presenter.show(message: "charge complete test: \(pass)")
        }
        Thread.sleep(forTimeInterval: 1)
        do {
            let value = try readBatteryVoltage()
            let min: Float = minChargedBatteryVoltage
            let max: Float = maxChargedBatteryVoltage
            let pass = (min <= value) && (value <= max)
            presenter.show(message: "charged voltage test: \(pass)")
        }
        do {
            let value = try readChargeCurrent()
            let max: Float = maxChargedCurrent
            let pass = value <= max
            presenter.show(message: "after charge current test: \(pass)")
        }
    }

    override func powerOn() throws {
        try powerOnUSB()
    }

    override func setup() throws {
        try super.setup()
    }
    
    func main() throws {
        try setup()
        
        try testCharging()
    }
    
}
