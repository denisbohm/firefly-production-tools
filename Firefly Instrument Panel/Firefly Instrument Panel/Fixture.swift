//
//  Fixture.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/15/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments

class Fixture {
    
    public var instrumentFinder = USBHIDFinder(name: "Firefly Instrument", vid: 0x0483, pid: 0x5710)
    public var instrumentManager: InstrumentManager? = nil
    public var serialWire1Instrument: SerialWireInstrument? = nil
    public var serialWire2Instrument: SerialWireInstrument? = nil
    public var colorInstrument: ColorInstrument? = nil
    public var buttonRelayInstrument: RelayInstrument? = nil
    public var usbPowerRelayInstrument: RelayInstrument? = nil
    public var voltageSenseRelayInstrument: RelayInstrument? = nil
    public var fillSupercapRelayInstrument: RelayInstrument? = nil
    public var drainSupercapRelayInstrument: RelayInstrument? = nil
    public var supercapToBatteryRelayInstrument: RelayInstrument? = nil
    public var simulatorToBatteryRelayInstrument: RelayInstrument? = nil
    public var voltageInstrument: VoltageInstrument? = nil
    public var auxiliaryVoltageInstrument: VoltageInstrument? = nil
    public var usbCurrentInstrument: CurrentInstrument? = nil
    public var batteryInstrument: BatteryInstrument? = nil
    public var storageInstrument: StorageInstrument? = nil
    public var fileSystem: FileSystem? = nil
    
    func collectInstruments() throws {
        let device = try instrumentFinder.find()
        try device.open()
        instrumentManager = InstrumentManager(device: device)
        try instrumentManager!.resetInstruments()
        try instrumentManager!.discoverInstruments()
        
        serialWire1Instrument = try instrumentManager!.getInstrument("SerialWire1")
        serialWire2Instrument = try instrumentManager!.getInstrument("SerialWire2")

        colorInstrument = try instrumentManager!.getInstrument("Color1")
        
        buttonRelayInstrument = try instrumentManager!.getInstrument("Relay1")
        usbPowerRelayInstrument = try instrumentManager!.getInstrument("Relay2")
        // Relay3 - USB data
        voltageSenseRelayInstrument = try instrumentManager!.getInstrument("Relay4")
        // Relay5 - Battery Sense
        fillSupercapRelayInstrument = try instrumentManager!.getInstrument("Relay6")
        drainSupercapRelayInstrument = try instrumentManager!.getInstrument("Relay7")
        supercapToBatteryRelayInstrument = try instrumentManager!.getInstrument("Relay8")
        simulatorToBatteryRelayInstrument = try instrumentManager!.getInstrument("Relay9")
        
        voltageInstrument = try instrumentManager!.getInstrument("Voltage2") // main rail voltage
        auxiliaryVoltageInstrument = try instrumentManager!.getInstrument("Voltage3") // auxiliary rail voltage
        
        usbCurrentInstrument = try instrumentManager!.getInstrument("Current1")
        
        batteryInstrument = try instrumentManager!.getInstrument("Battery1")
        
        storageInstrument = try instrumentManager!.getInstrument("Storage1")
        
        fileSystem = FileSystem(storageInstrument: storageInstrument!)
        try fileSystem!.inspect()
        NSLog("instrument storage file system entries:")
        for entry in fileSystem!.list() {
            NSLog("\t\(entry.name)\t\(entry.date)\t\(entry.length)\t@0x%08x", entry.address)
        }
    }
    
    func getSerialWireInstrument(_ identifier: String) -> SerialWireInstrument? {
        if identifier == "SerialWire1" {
            return serialWire1Instrument
        }
        if identifier == "SerialWire2" {
            return serialWire2Instrument
        }
        return nil
    }

}
