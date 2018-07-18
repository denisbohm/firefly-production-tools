//
//  Heap.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/28/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments

protocol HeapObject: class {
    
    var heapAddress: UInt32? { get set }
    var size: UInt32 { get }
    func locate(locator: Heap)
    func encode(encoder: Heap)
    func decode(decoder: Heap) throws
    
}

// 1) allocate and encode objects into ARM ABI (including object pointers and graphs)
// 2) transfer binary regions to MCU heap
// 3) transfer binary regions from MCU heap
// 4) decode object field changes only
//
// http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042f/IHI0042F_aapcs.pdf
class Heap {

    class Primitive<T>: HeapObject where T: BinaryConvertable {
        
        var heapAddress: UInt32? = nil
        var value: T
        
        init(value: T) {
            self.value = value
        }
        
        var size: UInt32 {
            get {
                return UInt32(MemoryLayout<T>.size)
            }
        }
        
        func locate(locator: Heap) {
            locator.allocate(object: self)
        }
        
        func encode(encoder: Heap) {
            encoder.write(address: heapAddress!, value: value)
        }
        
        func decode(decoder: Heap) throws {
            value = try decoder.read(address: heapAddress!)
        }
        
    }
    
    class Struct: HeapObject {
        
        var heapAddress: UInt32? = nil
        let fields: [HeapObject]
        
        init(fields: [HeapObject]) {
            self.fields = fields
        }
        
        var size: UInt32 {
            get {
                return fields.reduce(0) { return $0 + $1.size }
            }
        }
        
        func locate(locator: Heap) {
            self.heapAddress = locator.freeAddress
            
            for object in fields {
                object.locate(locator: locator)
            }
        }
        
        func encode(encoder: Heap) {
            for object in fields {
                object.encode(encoder: encoder)
            }
        }
        
        func decode(decoder: Heap) throws {
            for object in fields {
                try object.decode(decoder: decoder)
            }
        }
        
    }
    
    class Reference<T>: HeapObject where T: HeapObject {
        
        var heapAddress: UInt32? = nil
        let object: T
        
        init(object: T) {
            self.object = object
        }
        
        var size: UInt32 { get { return 4 } }
        
        func locate(locator: Heap) {
            locator.allocate(object: self)
            locator.locate(object: object)
        }
        
        func encode(encoder: Heap) {
            encoder.write(address: heapAddress!, value: object.heapAddress!)
            encoder.encode(object: object)
        }
        
        func decode(decoder: Heap) throws {
            decoder.decode(object: object)
        }
        
    }
    
    class PrimitiveStruct<T: BinaryConvertable>: Heap.Struct {
        
        let value: Heap.Primitive<T>
        
        init(value: T) {
            self.value = Heap.Primitive(value: value)
            super.init(fields: [self.value])
        }
        
    }
    
    let swapBytes = !isByteOrderNative(.littleEndian)
    var baseAddress: UInt32 = 0
    var freeAddress: UInt32 = 0
    var roots: [HeapObject] = []
    var pending: [HeapObject] = []
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }
    
    func setBase(address: UInt32) {
        baseAddress = (address + 0x3) & ~0x3 // align to 4-byte boundary
        freeAddress = address
    }
    
    func addRoot(object: HeapObject) {
        roots.append(object)
    }
    
    func locate() {
        freeAddress = baseAddress
        pending.removeAll()
        pending.append(contentsOf: roots)
        while !pending.isEmpty {
            let object = pending.removeFirst()
            object.locate(locator: self)
            freeAddress = (freeAddress + 0x3) & ~0x3 // align to 4-byte boundary
        }
    }
    
    func encode() {
        let count = Int(freeAddress - baseAddress)
        data = Data(count: count)
        pending.removeAll()
        pending.append(contentsOf: roots)
        while !pending.isEmpty {
            let object = pending.removeFirst()
            object.encode(encoder: self)
        }
    }
    
    func locate(object: HeapObject) {
        if object.heapAddress == nil {
            pending.append(object)
        }
    }
    
    func allocate(object: HeapObject) {
        let amount = UInt32(object.size - 1)
        freeAddress = (freeAddress + amount) & ~amount;
        object.heapAddress = freeAddress
        freeAddress += object.size
    }
    
    func write<B: BinaryConvertable>(address: UInt32, value: B) {
        let subdata = Binary.pack(value, swapBytes: swapBytes)
        let start = data.index(data.startIndex, offsetBy: Int(address - baseAddress))
        let end = data.index(start, offsetBy: subdata.count)
        data.replaceSubrange(start ..< end, with: subdata)
    }
    
    func encode(object: HeapObject) {
        if true /* not encoded */ {
            pending.append(object)
        }
    }
    
    func decode() throws {
        pending.removeAll()
        pending.append(contentsOf: roots)
        while !pending.isEmpty {
            let object = pending.removeFirst()
            try object.decode(decoder: self)
        }
    }
    
    func decode(object: HeapObject) {
        if true /* not decoded */ {
            pending.append(object)
        }
    }
    
    func read<B: BinaryConvertable>(address: UInt32) throws -> B {
        return try Binary.unpack(data, index: Int(address - baseAddress), swapBytes: swapBytes)
    }
    
}
