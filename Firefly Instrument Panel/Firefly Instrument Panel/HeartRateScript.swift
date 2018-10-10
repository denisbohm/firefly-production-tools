//
//  HeartRateScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 7/26/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation

class HeartRateScript: FireflyDesignScript, Script {

    func identify() throws {
        try fd_i2cm_bus_disable(bus: setupState!.buses["bq25120"]!)
        
        let heap = Heap()
        heap.setBase(address: setupState!.heap.freeAddress)
        try fd_i2cm_bus_enable(bus: setupState!.buses["heartRate"]!)
        let device = setupState!.devices["heartRate"]!
        
        // wake the device
        let wake = fd_gpio_t(port: 0, pin: 31)
        try fd_gpio_configure_output(gpio: wake)
        try fd_gpio_set(gpio: wake, value: false)
        Thread.sleep(forTimeInterval: 0.001)
        try fd_gpio_set(gpio: wake, value: true)
        Thread.sleep(forTimeInterval: 0.001)
 
        // wait for post to go high indicating boot process is complete (250 ms max)
        let post = fd_gpio_t(port: 0, pin: 28)
        try fd_gpio_configure_input(gpio: post)
        while true {
            if try fd_gpio_get(gpio: post) {
                break
            }
            Thread.sleep(forTimeInterval: 0.001)
        }

        // Byte 1: 0x44 - packet start
        // Byte 2: <byte count> - byte count to follow
        // Byte 3: <command>
        // Byte 4-n: <data> - command payload
        
        let packetStart: UInt8 = 0x44
        let getCommand: UInt8 = 0x08
        
        let postResultsRegister: UInt8 = 0x13
        let firmwareVerNumRegister: UInt8 = 0x44
        let deviceConfigNumRegister: UInt8 = 0x45
        let procPartIdRegister: UInt8 = 0x47

        // "get" command
        let getBytes = Heap.ByteArray(value: [packetStart, 5, getCommand,
               postResultsRegister,
               firmwareVerNumRegister,
               deviceConfigNumRegister,
               procPartIdRegister,
               ])
        let getIo = fd_i2cm_io_t(transfers: [fd_i2cm_transfer_t(direction: .tx, bytes: getBytes)])
        heap.addRoot(object: getIo)
        
        // "result" query
        let resultBytes = Heap.ByteArray(value: [UInt8](repeating: 0x00, count: 15))
        let resultIo = fd_i2cm_io_t(transfers: [fd_i2cm_transfer_t(direction: .rx, bytes: resultBytes)])
        heap.addRoot(object: resultIo)

        heap.locate()
        heap.encode()
        print(String(describing: heap))
        try serialWireDebug?.writeMemory(heap.baseAddress, data: heap.data)

        // write: [0x44, 5, 0x08, 0x13, 0x44, 0x45, 0x47]
        let writeResult = try fd_i2cm_device_io(heap: heap, device: device, io: getIo)
        // read: [0x44, 13, 0x20, 0x13, 0x00, 0x00, 0x44, 0x00, 0x00, 0x45, 0x00, 0x00, 0x47, 0x00, 0x00]
        let readResult = try fd_i2cm_device_io(heap: heap, device: device, io: resultIo)
        
        heap.data = try serialWireDebug!.readMemory(heap.baseAddress, length: UInt32(heap.data.count))
        try heap.decode()
        
        NSLog("\(resultBytes)")
    }
    
    func main() throws {
        try setup()
        
        try identify()
    }
    
}
