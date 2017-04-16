//
//  IntelHexParser.swift
//  IntelHex
//
//  Created by Denis Bohm on 4/11/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

import Cocoa

open class IntelHexParser: NSObject {

    public enum LocalError: Error {
        case InvalidStartCode
        case InvalidNibble
        case InvalidRecordType
        case InvalidChecksum
    }

    public static let asciiColon = UTF8.CodeUnit(0x3a) // :
    public static let ascii0 = UTF8.CodeUnit(0x30) // 0
    public static let ascii9 = UTF8.CodeUnit(0x39) // 9
    public static let asciiA = UTF8.CodeUnit(0x41) // A
    public static let asciiF = UTF8.CodeUnit(0x46) // F
    public static let asciiLowercaseA = UTF8.CodeUnit(0x61) // a
    public static let asciiLowercaseF = UTF8.CodeUnit(0x66) // f

    public static func parseHex(character: UTF8.CodeUnit) throws -> Int {
        if (ascii0 <= character) && (character <= ascii9) {
            return Int(character - ascii0)
        }
        if (asciiA <= character) && (character <= asciiF) {
            return 10 + Int(character - asciiA)
        }
        if (asciiLowercaseA <= character) && (character <= asciiLowercaseF) {
            return 10 + Int(character - asciiLowercaseA)
        }
        throw LocalError.InvalidNibble
    }

    open class RecordParser: NSObject {

        public let characters: [UTF8.CodeUnit]
        public var index: Int
        public var runningChecksum: UInt8

        public var computedChecksum: UInt8 {
            get {
                let (result, _) = UInt8.addWithOverflow(~runningChecksum, 1)
                return result
            }
        }

        public init(line: String) {
            self.characters = Array(line.utf8)
            self.index = 0
            self.runningChecksum = 0
        }

        open func parseStart() throws {
            if index >= characters.count {
                throw LocalError.InvalidStartCode
            }
            if characters[index] != asciiColon {
                throw LocalError.InvalidStartCode
            }
            index += 1
        }

        open func parseUInt4() throws -> Int {
            if index >= characters.count {
                throw LocalError.InvalidNibble
            }
            let character = characters[index]
            index += 1
            return try IntelHexParser.parseHex(character: character)
        }

        open func parseUInt8() throws -> UInt8 {
            let nibble1 = try parseUInt4()
            let nibble0 = try parseUInt4()
            let byte = UInt8((nibble1 << 4) | nibble0)
            (runningChecksum, _) = UInt8.addWithOverflow(runningChecksum, byte)
            return byte
        }

        open func parseUInt16() throws -> UInt16 {
            let byte1 = Int(try parseUInt8())
            let byte0 = Int(try parseUInt8())
            return UInt16((byte1 << 8) | byte0)
        }

        open func parseRecordType() throws -> IntelHex.RecordType {
            let rawValue = try parseUInt8()
            guard let recordType = IntelHex.RecordType(rawValue: rawValue) else {
                throw LocalError.InvalidRecordType
            }
            return recordType
        }

        open func parseData(byteCount: UInt8) throws -> Data {
            var data = Data()
            for _ in 0 ..< byteCount {
                let byte = try parseUInt8()
                data.append(byte)
            }
            return data
        }

        open func parse() throws -> IntelHex.Record {
            try parseStart()
            let byteCount = try parseUInt8()
            let addressOffset = try parseUInt16()
            let recordType = try parseRecordType()
            let data = try parseData(byteCount: byteCount)
            let computedChecksum = self.computedChecksum
            let checksum = try parseUInt8()
            if computedChecksum != checksum {
                throw LocalError.InvalidChecksum
            }
            return IntelHex.Record(addressOffset: addressOffset, recordType: recordType, data: data)
        }

    }

    open static func parse(line: String) throws -> IntelHex.Record {
        return try RecordParser(line: line).parse()
    }

    open static func parse(lines: [String]) throws -> [IntelHex.Record] {
        return try lines.map { try parse(line: $0) }
    }

    open static func parse(content: String) throws -> IntelHex {
        var lines: [String] = []
        content.enumerateLines { line, _ in lines.append(line) }
        return IntelHex(records: try parse(lines: lines))
    }

}
