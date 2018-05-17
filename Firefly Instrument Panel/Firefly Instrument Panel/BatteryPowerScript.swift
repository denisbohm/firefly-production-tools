//
//  BatteryPowerScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/11/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

class BatteryPowerScript: FixtureScript, Script {
    
    func main() throws {
        try setup()
        let conversion = try fixture.voltageInstrument?.convert()
        presenter.show(message: String(format: "target voltage %0.2f", conversion?.voltage ?? 0.0))
    }

}
