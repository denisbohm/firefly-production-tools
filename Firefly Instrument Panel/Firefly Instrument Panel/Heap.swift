//
//  Heap.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/28/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments

protocol HeapObject {
    
    var address: UInt32? { get set }
    
    func locate(address: UInt32) -> UInt32
    func encode(binary: Binary)
    func decode(binary: Binary) throws
    var size: UInt32 { get }
    
}

class Heap {

    let binary = Binary(byteOrder: .littleEndian)
    
    class HeapPrimitive<T>: HeapObject where T: BinaryConvertable {
        
        var address: UInt32? = nil
        var value: T
        
        init(value: T) {
            self.value = value
        }
        
        func locate(address: UInt32) -> UInt32 {
            self.address = address
            return address + size
        }
        
        func encode(binary: Binary) {
            binary.write(value)
        }
        
        func decode(binary: Binary) throws {
            value = try binary.read()
        }
        
        var size: UInt32 { get { return 4 } }
        
    }
    
    class HeapStruct: HeapObject {
        
        var address: UInt32? = nil
        let value: [HeapObject]
        
        init(value: [HeapObject]) {
            self.value = value
        }
        
        func locate(address: UInt32) -> UInt32 {
            self.address = address
            var location = address
            for heapObject in value {
                if heapObject.address == nil {
                    location = heapObject.locate(address: location)
                }
            }
            return location
        }
        
        func encode(binary: Binary) {
            for heapObject in value {
                heapObject.encode(binary: binary)
            }
        }
        
        func decode(binary: Binary) throws {
            for heapObject in value {
                try heapObject.decode(binary: binary)
            }
        }
        
        var size: UInt32 {
            get {
                return value.reduce(0) { return $0 + $1.size }
            }
        }
        
    }
    
    class Gpio: HeapStruct {
        
        var port: HeapPrimitive<UInt32>
        var pin: HeapPrimitive<UInt32>
        
        init(port: UInt32, pin: UInt32) {
            self.port = HeapPrimitive<UInt32>(value: port)
            self.pin = HeapPrimitive<UInt32>(value: pin)
            super.init(value: [self.port, self.pin])
        }
        
    }
    
    class fd_spim_bus_t: HeapStruct {
        
        let instance: HeapPrimitive<UInt32>
        let sclk: Gpio
        let mosi: Gpio
        let miso: Gpio
        let frequency: HeapPrimitive<UInt32>
        let mode: HeapPrimitive<UInt32>
        
        init(instance: UInt32, sclk: Gpio, mosi: Gpio, miso: Gpio, frequency: UInt32, mode: UInt32) {
            self.instance = HeapPrimitive<UInt32>(value: instance)
            self.sclk = sclk
            self.mosi = mosi
            self.miso = miso
            self.frequency = HeapPrimitive<UInt32>(value: frequency)
            self.mode = HeapPrimitive<UInt32>(value: mode)
            super.init(value: [self.instance, self.sclk, self.mosi, self.miso, self.frequency, self.mode])
        }
        
    }
    
    class HeapEncoder {
        
        func encode(binary: Binary, object: HeapObject) {
            let _ = object.locate(address: 0x20000000)
            let binary = Binary(byteOrder: .littleEndian)
            object.encode(binary: binary)
        }
        
    }

}
