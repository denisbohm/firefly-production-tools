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

class ViewController: NSViewController {

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
    
    let fixture = Fixture()

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
        let serialWireDebug = FDSerialWireDebug()
        serialWireDebug.serialWire = fixture.serialWireInstrument!
        do {
            let serialWire = serialWireDebug.serialWire!
            serialWire.setReset(true)
            try serialWire.write()
            Thread.sleep(forTimeInterval: 0.1)
            serialWire.setReset(false)
            try serialWire.write()
            Thread.sleep(forTimeInterval: 1.0)
            
            serialWireDebug.resetDebugPort()
            try serialWire.write()
            
            var debugPortIDCode: UInt32 = 0
            try serialWireDebug.readPortIDCode(&debugPortIDCode)
            NSLog(FDSerialWireDebug.debugPortIDCodeDescription(debugPortIDCode))

            try serialWireDebug.initializeDebugPort()
            try serialWireDebug.halt()
            
            // !!! In "fresh" boards there seems to be interrupts pending, this seems to clear it (this needs more investigation) -denis
            try serialWireDebug.writeMemory(0xE000ED0C, value: 0x05FA0001)
            try serialWireDebug.step()
            
            try serialWireDebug.initializeAccessPort()
            var cpuID: UInt32 = 0
            try serialWireDebug.readCPUID(&cpuID)
            NSLog(FDSerialWireDebug.cpuIDDescription(cpuID))
        } catch {
            NSLog("error \(error)")
        }
    }
    
    @IBAction func swd2Identify(_ sender: Any) {
        NSLog("SWD 2 identify")
    }
    
}
