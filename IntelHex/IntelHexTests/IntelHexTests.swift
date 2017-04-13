//
//  IntelHexTests.swift
//  IntelHexTests
//
//  Created by Denis Bohm on 4/11/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

import XCTest
@testable import IntelHex

class IntelHexTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testParseLine() {
        guard let record = try? IntelHexParser.parse(line: ":0300300002337A1E") else {
            XCTFail()
            return
        }
        XCTAssert(record.addressOffset == 0x0030)
        XCTAssert(record.recordType == .data)
        XCTAssert(record.data == Data(bytes: Array<UInt8>(arrayLiteral: 0x02, 0x33, 0x7A)))
    }

    func testParseLines() {
        guard let records = try? IntelHexParser.parse(lines: [":0300300002337A1E", ":00000001FF"]) else {
            XCTFail()
            return
        }
        XCTAssert(records.count == 2)
        if records.count != 2 {
            return
        }
        let record0 = records[0]
        XCTAssert(record0.addressOffset == 0x0030)
        XCTAssert(record0.recordType == .data)
        XCTAssert(record0.data == Data(bytes: Array<UInt8>(arrayLiteral: 0x02, 0x33, 0x7A)))
        let record1 = records[1]
        XCTAssert(record1.addressOffset == 0x0000)
        XCTAssert(record1.recordType == .endOfFile)
        XCTAssert(record1.data == Data())
    }

    func testParseContent() {
        guard let intelHex = try? IntelHexParser.parse(content: ":0300300002337A1E\n:00000001FF") else {
            XCTFail()
            return
        }
        let records = intelHex.records
        XCTAssert(records.count == 2)
        if records.count != 2 {
            return
        }
        let record0 = records[0]
        XCTAssert(record0.addressOffset == 0x0030)
        XCTAssert(record0.recordType == .data)
        XCTAssert(record0.data == Data(bytes: Array<UInt8>(arrayLiteral: 0x02, 0x33, 0x7A)))
        let record1 = records[1]
        XCTAssert(record1.addressOffset == 0x0000)
        XCTAssert(record1.recordType == .endOfFile)
        XCTAssert(record1.data == Data())
    }

    func testParseInvalidStartCode() {
        XCTAssertThrowsError(try IntelHexParser.parse(line: ""))
        XCTAssertThrowsError(try IntelHexParser.parse(line: "!"))
    }

    func testParseInvalidNibble() {
        XCTAssertThrowsError(try IntelHexParser.parse(line: ":"))
        XCTAssertThrowsError(try IntelHexParser.parse(line: ":!"))
    }

    func testParseInvalidRecordType() {
        XCTAssertThrowsError(try IntelHexParser.parse(line: ":000000FF"))
    }

    func testParseInvalidChecksum() {
        XCTAssertThrowsError(try IntelHexParser.parse(line: ":00000000FF"))
    }

    func testGetAddressBounds() throws {
        let intelHex = IntelHex(records: [
            IntelHex.Record(addressOffset: 0x01, recordType: .data, data: Data(bytes: [0x01])),
            IntelHex.Record(addressOffset: 0x02, recordType: .data, data: Data(bytes: [0x02])),
            IntelHex.Record(addressOffset: 0x00, recordType: .data, data: Data(bytes: [0x00])),
            ])
        let (min, max) = try intelHex.getAddressBounds()
        XCTAssert(min == 0)
        XCTAssert(max == 3)
    }

    func testExtendedSegmentAddress() throws {
        let intelHex = IntelHex(records: [
            IntelHex.Record(addressOffset: 0x0000, recordType: .extendedSegmentAddress, data: Data(bytes: [0xF0, 0x00])),
            IntelHex.Record(addressOffset: 0x0001, recordType: .data, data: Data(bytes: [0x01])),
            ])
        let (min, max) = try intelHex.getAddressBounds()
        XCTAssert(min == 0xF0001)
        XCTAssert(max == 0xF0002)
    }
    
    func testExtendedLinearAddress() throws {
        let intelHex = IntelHex(records: [
            IntelHex.Record(addressOffset: 0x0000, recordType: .extendedLinearAddress, data: Data(bytes: [0xF0, 0x00])),
            IntelHex.Record(addressOffset: 0x0001, recordType: .data, data: Data(bytes: [0x01])),
            ])
        let (min, max) = try intelHex.getAddressBounds()
        XCTAssert(min == 0xF0000001)
        XCTAssert(max == 0xF0000002)
    }

    func testStartSegmentAddress() throws {
        let intelHex = IntelHex(records: [
            IntelHex.Record(addressOffset: 0x0000, recordType: .startSegmentAddress, data: Data(bytes: [0xF0, 0x00])),
            IntelHex.Record(addressOffset: 0x0001, recordType: .data, data: Data(bytes: [0x01])),
            ])
        let (min, max) = try intelHex.getAddressBounds()
        XCTAssert(min == 0x0001)
        XCTAssert(max == 0x0002)
    }

    func testStartLinearAddress() throws {
        let intelHex = IntelHex(records: [
            IntelHex.Record(addressOffset: 0x0000, recordType: .startLinearAddress, data: Data(bytes: [0xF0, 0x00])),
            IntelHex.Record(addressOffset: 0x0001, recordType: .data, data: Data(bytes: [0x01])),
            ])
        let (min, max) = try intelHex.getAddressBounds()
        XCTAssert(min == 0x0001)
        XCTAssert(max == 0x0002)
    }

    func testCombineData() {
        guard let intelHex = try? IntelHexParser.parse(content: ":0300300002337A1E\n:00000001FF") else {
            XCTFail()
            return
        }
        guard let result = try? intelHex.combineData() else {
            XCTFail()
            return
        }
        XCTAssert(result.addressBounds.min == 0x30)
        XCTAssert(result.addressBounds.max == 0x33)
        XCTAssert(result.data == Data(bytes: Array<UInt8>(arrayLiteral: 0x02, 0x33, 0x7A)))
    }

    func testNoDataRecordsFound() {
        XCTAssertThrowsError(try IntelHex(records: []).getAddressBounds())
    }

    func testFormatRecord() {
        let record = IntelHex.Record(addressOffset: 0x30, recordType: .data, data: Data(bytes: Array<UInt8>(arrayLiteral: 0x02, 0x33, 0x7A)))
        guard let string = try? IntelHexFormatter.format(record: record) else {
            XCTFail()
            return
        }
        XCTAssert(string == ":0300300002337A1E")
    }

    func testFormatRecords() {
        let records = [
            IntelHex.Record(addressOffset: 0x30, recordType: .data, data: Data(bytes: Array<UInt8>(arrayLiteral: 0x02, 0x33, 0x7A))),
            IntelHex.Record(addressOffset: 0x00, recordType: .endOfFile, data: Data())
        ]
        guard let strings = try? IntelHexFormatter.format(records: records) else {
            XCTFail()
            return
        }
        XCTAssert(strings == [":0300300002337A1E", ":00000001FF"])
    }

    func testFormatIntelHex() {
        let intelHex = IntelHex(records: [
            IntelHex.Record(addressOffset: 0x30, recordType: .data, data: Data(bytes: Array<UInt8>(arrayLiteral: 0x02, 0x33, 0x7A))),
            IntelHex.Record(addressOffset: 0x00, recordType: .endOfFile, data: Data())
        ])
        guard let string = try? IntelHexFormatter.format(intelHex: intelHex) else {
            XCTFail()
            return
        }
        XCTAssert(string == ":0300300002337A1E\n:00000001FF")
    }

    func testFormatInvalidDataCount() {
        XCTAssertThrowsError(try IntelHexFormatter.format(record: IntelHex.Record(addressOffset: 0x0000, recordType: .data, data: Data(bytes: Array<UInt8>(repeating: 0x00, count: 256)))))
    }

}
