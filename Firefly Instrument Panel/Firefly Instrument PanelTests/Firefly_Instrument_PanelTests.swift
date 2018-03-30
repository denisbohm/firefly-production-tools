//
//  Firefly_Instrument_PanelTests.swift
//  Firefly Instrument PanelTests
//
//  Created by Denis Bohm on 3/15/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import XCTest
@testable import Firefly_Instrument_Panel

class Firefly_Instrument_PanelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let heap = Heap()
        heap.setBase(address: 0x20000000)

        let TWIM0: UInt32 = 0x40003000
        let scl = SpiFlashTestScript.fd_gpio_t(port: 1, pin: 12)
        let sda = SpiFlashTestScript.fd_gpio_t(port: 1, pin: 13)
        let bus = SpiFlashTestScript.fd_i2cm_bus_t(instance: TWIM0, scl: scl, sda: sda, frequency: 100000)
        heap.addRoot(object: bus)
        
        let address: UInt32 = 0x6a // bq25120 7-bit address
        let device = SpiFlashTestScript.fd_i2cm_device_t(bus: bus, address: address)
        heap.addRoot(object: device)
        
        heap.encode()
        NSLog("\(heap.data)")
    }
    
}
