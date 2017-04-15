//
//  IntelHex.swift
//  IntelHex
//
//  Created by Denis Bohm on 4/11/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

import Cocoa

open class IntelHex: NSObject {

    public enum LocalError : Error {
        case NoDataRecordsFound
    }

    public enum RecordType: UInt8 {
        case data = 0
        case endOfFile = 1
        case extendedSegmentAddress = 2
        case startSegmentAddress = 3
        case extendedLinearAddress = 4
        case startLinearAddress = 5
    }

    public struct Record {
        var addressOffset: UInt16
        var recordType: RecordType
        var data: Data
    }

    public var records: [Record]

    public init(records: [Record]) {
        self.records = records
    }

    public init(data: Data, address: UInt32, recordByteCount: Int = 32) {
        records = []
        var lastExtendedLinearAddress: UInt16 = 0
        var offset = 0
        while offset < data.count {
            let extendedLinearAddress = UInt16((address + UInt32(offset)) >> 16)

            if extendedLinearAddress != lastExtendedLinearAddress {
                let binary = Binary(byteOrder: .littleEndian)
                binary.write(extendedLinearAddress)
                records.append(Record(addressOffset: 0, recordType: .extendedLinearAddress, data: binary.data))
                lastExtendedLinearAddress = extendedLinearAddress
            }

            var count = data.count - offset
            if count > recordByteCount {
                count = recordByteCount
            }
            records.append(Record(addressOffset: UInt16((Int(address) + offset) & 0xffff), recordType: .data, data: data.subdata(in: offset ..< (offset + count))))
            offset += count
        }
    }

    open func traverseDataRecordsWithAddress(closure: (_ address: UInt32, _ record: Record) -> Void) {
        var extendedAddress: UInt32 = 0
        traversal:
        for record in records {
            switch record.recordType {
            case .data:
                let address = extendedAddress + UInt32(record.addressOffset)
                closure(address, record)
            case .endOfFile:
                break traversal
            case .extendedSegmentAddress:
                let byte0 = UInt32(record.data[0])
                let byte1 = UInt32(record.data[1])
                extendedAddress = ((byte0 << 8) | byte1) << 4
            case .startSegmentAddress:
                break
            case .extendedLinearAddress:
                let byte0 = UInt32(record.data[0])
                let byte1 = UInt32(record.data[1])
                extendedAddress = (byte0 << 24) | (byte1 << 16)
            case .startLinearAddress:
                break
            }
        }
    }

    open func getAddressBounds() throws -> (min: UInt32, max: UInt32) {
        var min: UInt32?
        var max: UInt32?
        traverseDataRecordsWithAddress { (_ address: UInt32, _ record: Record) -> Void in
            if (min == nil) || (address < min!) {
                min = address
            }
            let last = address + UInt32(record.data.count)
            if (max == nil) || (last > max!) {
                max = last
            }
        }
        if (min == nil) || (max == nil) {
            throw LocalError.NoDataRecordsFound
        }
        return (min: min!, max: max!)
    }

    open func combineData(fill: UInt8 = 0x00) throws -> (addressBounds: (min: UInt32, max: UInt32), data: Data) {
        let (min, max) = try getAddressBounds()
        let count = Int(max) - Int(min)
        var bytes = [UInt8](repeating: fill, count: count)
        traverseDataRecordsWithAddress { (_ address: UInt32, _ record: Record) -> Void in
            let from = Int(address - min)
            let to = from + record.data.count
            bytes.replaceSubrange(from ..< to, with: record.data)
        }
        return (addressBounds: (min: min, max: max), data: Data(bytes: bytes))
    }

}
