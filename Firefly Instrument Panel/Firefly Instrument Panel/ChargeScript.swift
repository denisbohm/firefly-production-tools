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
        return 3.9
    }
    
    func readChargeCurrent() throws -> Float {
        return 0.001
    }
    
    func testCharging() throws {
        // switch DUT to USB power (first switch charged super cap into bat+ to avoid power loss)
        try fixture.supercapToBatteryRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 0.1)
        try fixture.usbPowerRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 0.1)
        do {
            let value = try fd_gpio_get(gpio: usbPowerPortPin)
            let pass = value == true
            presenter.show(message: String(format: "USB power good pin test: \(pass)"))
        }
        
        try fixture.drainSupercapRelayInstrument?.set(false)
        try fixture.fillSupercapRelayInstrument?.set(false)
        try fixture.supercapToBatteryRelayInstrument?.set(false)
        try fixture.simulatorToBatteryRelayInstrument?.set(false)
        
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
            try fixture.fillSupercapRelayInstrument?.set(true)
            Thread.sleep(forTimeInterval: 5)
            try fixture.fillSupercapRelayInstrument?.set(false)
        }
        
        // connect DUT to supercap power
        try fixture.supercapToBatteryRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 0.1)
        do {
            let value = try fd_gpio_get(gpio: chargeStatusPortPin)
            let expected = false
            let pass = value == expected
            presenter.show(message: "charge status pin test: \(pass)")
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
            presenter.show(message: "waiting for battery charge to complete...")
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

    override func setup() throws {
        try super.setup()
    }
    
    func main() throws {
        try setup()
        try testCharging()
    }
    
}
