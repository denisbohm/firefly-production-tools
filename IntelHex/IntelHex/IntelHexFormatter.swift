//
//  IntelHexFormatter.swift
//  IntelHex
//
//  Created by Denis Bohm on 4/12/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

import Cocoa

open class IntelHexFormatter: NSObject {

    public enum LocalError: Error {
        case InvalidDataCount
    }

    open class RecordFormatter: NSObject {

        public let record: IntelHex.Record
        public var string: String
        public var runningChecksum: UInt8

        public var computedChecksum: UInt8 {
            get {
                let (result, _) = UInt8.addWithOverflow(~runningChecksum, 1)
                return result
            }
        }

        public init(record: IntelHex.Record) {
            self.record = record
            self.string = ""
            self.runningChecksum = 0
        }

        open func formatStart() {
            string += ":"
        }

        open func formatUInt8(byte: UInt8) {
            string += String(format: "%02X", byte)
            (runningChecksum, _) = UInt8.addWithOverflow(runningChecksum, byte)
        }

        open func formatUInt16(value: UInt16) {
            formatUInt8(byte: UInt8(value >> 8))
            formatUInt8(byte: UInt8(value & 0xff))
        }

        open func formatRecordType(recordType: IntelHex.RecordType) {
            formatUInt8(byte: recordType.rawValue)
        }

        open func formatData(data: Data) {
            for byte in data {
                formatUInt8(byte: byte)
            }
        }

        open func format() throws -> String {
            if record.data.count > 255 {
                throw LocalError.InvalidDataCount
            }
            formatStart()
            formatUInt8(byte: UInt8(record.data.count))
            formatUInt16(value: record.addressOffset)
            formatRecordType(recordType: record.recordType)
            formatData(data: record.data)
            formatUInt8(byte: self.computedChecksum)
            return string
        }

    }

    public static func format(record: IntelHex.Record) throws -> String {
        return try RecordFormatter(record: record).format()
    }

    public static func format(records: [IntelHex.Record]) throws -> [String] {
        return try records.map { try format(record: $0) }
    }

    public static func format(intelHex: IntelHex) throws -> String {
        return try format(records: intelHex.records).joined(separator: "\n")
    }

}
