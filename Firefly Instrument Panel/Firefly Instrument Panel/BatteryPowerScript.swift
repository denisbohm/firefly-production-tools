//
//  BatteryPowerScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/11/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation

class BatteryPowerScript: FixtureScript, Script {
    
    enum LocalError: Error {
        case conversionError
    }
    
    func main() throws {
        self.batteryVoltage = 3.6
        
        try setup()
        
        try fixture.voltageSenseRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 2.0)
        let conversion = try fixture.voltageInstrument?.convert()
        presenter.show(message: String(format: "target voltage %0.2f", conversion?.voltage ?? 0.0))
        try fixture.voltageSenseRelayInstrument?.set(false)
    }

}
