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

    @IBOutlet var buttonRelaySegmentedControl: NSSegmentedControl!
    @IBOutlet var usbPowerRelaySegmentedControl: NSSegmentedControl!
    @IBOutlet var voltageSenseRelaySegmentedControl: NSSegmentedControl!
    @IBOutlet var fillSupercapRelaySegmentedControl: NSSegmentedControl!
    @IBOutlet var drainSupercapRelaySegmentedControl: NSSegmentedControl!
    @IBOutlet var supercapToBatteryRelaySegmentedControl: NSSegmentedControl!
    @IBOutlet var simulatorToBatteryRelaySegmentedControl: NSSegmentedControl!
    @IBOutlet var batteryVoltageTextField: NSTextField!
    @IBOutlet var mainVoltageTextField: NSTextField!
    @IBOutlet var auxiliaryVoltageTextField: NSTextField!
    @IBOutlet var usbCurrentTextField: NSTextField!
    @IBOutlet var batterySimulatorCurrentTextField: NSTextField!
    @IBOutlet var batterySimulatorVoltageTextField: NSTextField!
    @IBOutlet var batterySimulatorEnableSegmentedControl: NSSegmentedControl!
    @IBOutlet var swd1TextField: NSTextField!
    @IBOutlet var swd2TextField: NSTextField!
    @IBOutlet var messageTextView: NSTextView!
    
    let fixture = Fixture()
    var runner: Runner? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func attach(_ sender: Any) {
        do {
            try fixture.collectInstruments()
        } catch let error {
            NSLog("error: \(error)")
        }
    }
    
    @IBAction func update(_ sender: Any) {
        if let conversion = try? fixture.voltageInstrument?.convert() {
            mainVoltageTextField.stringValue = String(format: "%0.1f V", conversion!.voltage)
        }
        if let conversion = try? fixture.auxiliaryVoltageInstrument?.convert() {
            auxiliaryVoltageTextField.stringValue = String(format: "%0.1f V", conversion!.voltage)
        }
        if let conversion = try? fixture.usbCurrentInstrument?.convert() {
            usbCurrentTextField.stringValue = String(format: "%0.1f mA", conversion!.current * 1000.0)
        }
        if let conversion = try? fixture.batteryInstrument?.convert() {
            batterySimulatorCurrentTextField.stringValue = String(format: "%0.1f mA", conversion!.current * 1000.0)
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func set(relayInstrument: RelayInstrument?, segmentedControl: NSSegmentedControl) {
        let value = segmentedControl.selectedSegment != 0
        do {
            try relayInstrument?.set(value)
        } catch let error {
            NSLog("error: \(error)")
        }
    }
    
    @IBAction func buttonRelayChanged(_ sender: Any) {
        set(relayInstrument: fixture.buttonRelayInstrument, segmentedControl: buttonRelaySegmentedControl)
    }
    
    @IBAction func usbPowerRelayChanged(_ sender: Any) {
        set(relayInstrument: fixture.usbPowerRelayInstrument, segmentedControl: usbPowerRelaySegmentedControl)
    }
    
    @IBAction func voltageSenseRelayChanged(_ sender: Any) {
        set(relayInstrument: fixture.voltageSenseRelayInstrument, segmentedControl: voltageSenseRelaySegmentedControl)
    }
    
    @IBAction func fillSupercapRelayChanged(_ sender: Any) {
        set(relayInstrument: fixture.fillSupercapRelayInstrument, segmentedControl: fillSupercapRelaySegmentedControl)
    }
    
    @IBAction func drainSupercapRelayChanged(_ sender: Any) {
        set(relayInstrument: fixture.drainSupercapRelayInstrument, segmentedControl: drainSupercapRelaySegmentedControl)
    }
    
    @IBAction func supercapToBatteryRelayChanged(_ sender: Any) {
        set(relayInstrument: fixture.supercapToBatteryRelayInstrument, segmentedControl: supercapToBatteryRelaySegmentedControl)
    }
    
    @IBAction func simulatorToBatteryRelayChanged(_ sender: Any) {
        set(relayInstrument: fixture.simulatorToBatteryRelayInstrument, segmentedControl: simulatorToBatteryRelaySegmentedControl)
    }
    
    @IBAction func batterySimulatorVoltageChanged(_ sender: Any) {
        NSLog("battery simulator voltage changed")
        guard let voltage = Float(batterySimulatorVoltageTextField.stringValue) else {
            return
        }
        try? fixture.batteryInstrument?.setVoltage(voltage)
    }
    
    @IBAction func batterySimulatorEnableChanged(_ sender: Any) {
        NSLog("battery simulator enabled changed")
        let enable = batterySimulatorEnableSegmentedControl.selectedSegment != 0
        try? fixture.batteryInstrument?.setEnabled(enable)
    }
    
    @IBAction func swd1Identify(_ sender: Any) {
        NSLog("SWD 1 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self))
    }
    
    @IBAction func flashIdentify(_ sender: Any) {
        NSLog("flash identify")
        run(script: SpiFlashTestScript(fixture: fixture, presenter: self))
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
