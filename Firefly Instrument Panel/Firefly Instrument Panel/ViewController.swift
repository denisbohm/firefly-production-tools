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
    
    @IBAction func batteryPower(_ sender: Any) {
        NSLog("Battery Power")
        run(script: BatteryPowerScript(fixture: fixture, presenter: self))
    }
    
    @IBAction func swd1Identify(_ sender: Any) {
        NSLog("SWD 1 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    @IBAction func swd2Identify(_ sender: Any) {
        NSLog("SWD 2 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire2"))
    }
    
}
