//
//  ViewController.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/15/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa
import ARMSerialWireDebug
import FireflyInstruments

class ViewController: FireflyInstrumentsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func swd1Identify(_ sender: Any) {
        NSLog("SWD 1 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    @IBAction func swd2Identify(_ sender: Any) {
        NSLog("SWD 2 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire2"))
    }
    
    @IBAction func batteryPower(_ sender: Any) {
        NSLog("Battery Power")
        run(script: BatteryPowerScript(fixture: fixture, presenter: self))
    }
    
    @IBAction func usbPower(_ sender: Any) {
        NSLog("USB Power")
        run(script: UsbPowerScript(fixture: fixture, presenter: self))
    }
    
    @IBAction func quiescent(_ sender: Any) {
        NSLog("quiescent current")
        guard let nrf5URL = Bundle.main.url(forResource: "fd_quiescent_test_nrf5", withExtension: "hex") else {
            NSLog("fd_quiescent_test_nrf5.hex not found")
            return
        }
        guard let nrf5Firmware = try? IntelHexParser.parse(content: String(contentsOf: nrf5URL)) else {
            NSLog("fd_quiescent_test_nrf5.hex parse error")
            return
        }
        guard let apolloURL = Bundle.main.url(forResource: "fd_quiescent_test_apollo", withExtension: "hex") else {
            NSLog("fd_quiescent_test_apollo.hex not found")
            return
        }
        guard let apolloFirmware = try? IntelHexParser.parse(content: String(contentsOf: apolloURL)) else {
            NSLog("fd_quiescent_test_apollo.hex parse error")
            return
        }
        run(script: QuiescentScript(fixture: fixture, presenter: self, nrf5Firmware: nrf5Firmware, apolloFirmware: apolloFirmware))
    }
    
}
