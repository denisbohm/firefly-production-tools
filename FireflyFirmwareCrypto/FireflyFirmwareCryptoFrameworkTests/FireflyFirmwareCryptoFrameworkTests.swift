//
//  FireflyFirmwareCryptoFrameworkTests.swift
//  FireflyFirmwareCryptoFrameworkTests
//
//  Created by Denis Bohm on 4/14/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

import XCTest
@testable import FireflyFirmwareCryptoFramework

class FireflyFirmwareCryptoFrameworkTests: XCTestCase {
    
    func testCryptDecrypt() throws {
        let address: UInt32 = 0x1
        let data = Data(bytes: Array<UInt8>(repeating: 0x5a, count: 1))
        let intelHex = IntelHex(data: data, address: address)
        let firmware = try IntelHexFormatter.format(intelHex: intelHex)
        let key = Data(bytes: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f])
        let version = FirmwareCrypto.Version(major: 1, minor: 2, revision: 3, commit: Data(bytes: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13]))
        let encryptedFirmware = try FirmwareCrypto.encrypt(firmware: firmware, key: key, version: version)

        let (firmware: decryptedData, metadata: metadata) = try FirmwareCrypto.decrypt(encryptedFirmware: encryptedFirmware, key: key)
        XCTAssert(metadata.version == version)
        XCTAssert(metadata.address == address)
        XCTAssert(decryptedData == data)
    }
    
}
