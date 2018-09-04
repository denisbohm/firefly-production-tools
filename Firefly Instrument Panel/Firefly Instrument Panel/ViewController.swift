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

class ViewController: NSViewController, Presenter {

    @IBOutlet var messageTextView: NSTextView!
    
    let fixture = Fixture()
    var runner: Runner? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func cancel(_ sender: Any) {
        if let runner = runner {
            runner.cancel()
        }
    }
    
    func loadFirmware(resource: String) -> IntelHex? {
        guard let path = Bundle.main.path(forResource: resource, ofType: "hex") else {
            show(message: "can't find resource \"\(resource)\"")
            return nil
        }
        guard let content = try? String(contentsOfFile: path) else {
            show(message: "can't read resource \"\(resource)\"")
            return nil
        }
        return try? IntelHexParser.parse(content: content)
    }
    
    @IBAction func programFirmware(_ sender: Any) {
        NSLog("Program Firmware")
        guard
            let nrf5Boot = loadFirmware(resource: "atlas_boot"),
            let nrf5Application = loadFirmware(resource: "atlas_app"),
            let nrf5Softdevice = loadFirmware(resource: "s140_nrf52_6.0.0_softdevice"),
            let apolloApplication = loadFirmware(resource: "atlas_display")
        else {
            show(message: "Can't load firmware!")
            return
        }
        run(script: DualProgramScript(fixture: fixture, presenter: self, nrf5Boot: nrf5Boot, nrf5Application: nrf5Application, nrf5Softdevice: nrf5Softdevice, serialNumber: 0, apolloApplication: apolloApplication))
    }
    
    @IBAction func quiescentTest(_ sender: Any) {
        NSLog("quiescent test")
        guard
            let nrf5Firmware = loadFirmware(resource: "fd_quiescent_test_nrf5"),
            let apolloFirmware = loadFirmware(resource: "fd_quiescent_test_apollo")
        else {
                show(message: "Can't load firmware!")
                return
        }
        run(script: QuiescentScript(fixture: fixture, presenter: self, nrf5Firmware: nrf5Firmware, apolloFirmware: apolloFirmware))
    }
    
    @IBAction func batteryPower(_ sender: Any) {
        NSLog("Battery Power")
        run(script: BatteryPowerScript(fixture: fixture, presenter: self))
    }
    
    @IBAction func swd1Identify(_ sender: Any) {
        NSLog("SWD 1 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    @IBAction func spiFlashTest(_ sender: Any) {
        NSLog("SPI flash test")
        run(script: SpiFlashTestScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    @IBAction func swd2Identify(_ sender: Any) {
        NSLog("SWD 2 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire2"))
    }
    
    @IBAction func displayTest(_ sender: Any) {
        NSLog("display test")
        run(script: DisplayTestScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire2"))
    }
    
    @IBAction func chargeTest(_ sender: Any) {
        NSLog("charge test")
        run(script: ChargeScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    @IBAction func heartRateTest(_ sender: Any) {
        NSLog("heart rate test")
        run(script: HeartRateScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    func run(script: Script) {
        messageTextView.string = ""
        
        runner = Runner(fixture: fixture, presenter: self, script: script)
        runner?.start()
    }
    
    func showOnMain(message: String) {
        messageTextView.textStorage?.append(NSAttributedString(string: message + "\n"))
        messageTextView.scrollToEndOfDocument(nil)
    }
    
    func show(message: String) {
        DispatchQueue.main.async() {
            self.showOnMain(message: message)
        }
    }
    
    func completedOnMain() {
        runner = nil
    }
    
    func completed() {
        DispatchQueue.main.async() {
            self.completedOnMain()
        }
    }
    
}
