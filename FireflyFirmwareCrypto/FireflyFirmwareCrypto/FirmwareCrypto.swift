//
//  FirmwareCrypto.swift
//  FireflyFirmwareCrypto
//
//  Created by Denis Bohm on 4/14/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

import Cocoa

open class FirmwareCrypto: NSObject {

    public enum LocalError: Error {
        case invalidFirmware
    }

    public struct Version: Equatable {

        public let major: UInt32
        public let minor: UInt32
        public let revision: UInt32
        public let commit: Data

        static public func ==(lhs: Version, rhs: Version) -> Bool {
            return (lhs.major == rhs.major) && (lhs.minor == rhs.minor) && (lhs.revision == rhs.revision) && (lhs.commit == rhs.commit)
        }

    }

    public struct Metadata {

        public let flags: UInt32
        public let version: Version
        public let address: UInt32
        public let length: UInt32
        public let initializationVector: Data
        public let encryptedHash: Data
        public let uncryptedHash: Data

        public let data: Data

        public init(flags: UInt32, version: Version, address: UInt32, length: UInt32, initializationVector: Data, encryptedHash: Data, uncryptedHash: Data) {
            self.flags = flags
            self.version = version
            self.address = address
            self.length = length
            self.initializationVector = initializationVector
            self.encryptedHash = encryptedHash
            self.uncryptedHash = uncryptedHash

            let binary = Binary(byteOrder: .littleEndian)
            binary.write(flags)
            binary.write(version.major)
            binary.write(version.minor)
            binary.write(version.revision)
            binary.write(version.commit)
            binary.write(address)
            binary.write(length)
            binary.write(initializationVector)
            binary.write(encryptedHash)
            binary.write(uncryptedHash)
            data = binary.data
        }

        public init(data: Data) throws {
            self.data = data

            let binary = Binary(data: data, byteOrder: .littleEndian)
            self.flags = try binary.read()
            let major: UInt32 = try binary.read()
            let minor: UInt32 = try binary.read()
            let revision: UInt32 = try binary.read()
            let commit: Data = try binary.read(length: 20)
            self.version = Version(major: major, minor: minor, revision: revision, commit: commit)
            self.address = try binary.read()
            self.length = try binary.read()
            self.initializationVector = try binary.read(length: 16)
            self.encryptedHash = try binary.read(length: 20)
            self.uncryptedHash = try binary.read(length: 20)
        }

        public func isEqualTo(metadata: Metadata) -> Bool {
            return
                flags == metadata.flags &&
                    version == metadata.version &&
                    address == metadata.address &&
                    length == metadata.length &&
                    initializationVector == metadata.initializationVector &&
                    encryptedHash == metadata.encryptedHash &&
                    uncryptedHash == metadata.uncryptedHash
        }

    }

    public static let metadataBlockSize = 1024

    public static func pad(data: Data, blockSize: Int) throws -> Data {
        if (data.count % blockSize) == 0 {
            return data
        }
        var paddedData = data
        paddedData.append(try Crypto.random(UInt(blockSize - (data.count % blockSize))))
        return paddedData
    }

    public static func encrypt(firmware: String, key: Data, version: Version) throws -> Data {
        let intelHex = try IntelHexParser.parse(content: firmware)
        let (addressBounds: (min: min, max: max), data: data) = try intelHex.combineData()
        let paddedData = try FirmwareCrypto.pad(data: data, blockSize: 16);
        let initializationVector = try Crypto.random(16)
        let encryptedData = try Crypto.encrypt(paddedData, key: key, initializationVector: initializationVector)

        let metadata = Metadata(flags: 0, version: version, address: min, length: max - min, initializationVector: initializationVector, encryptedHash: Crypto.sha1(encryptedData), uncryptedHash: Crypto.sha1(data))

        var uncryptedMetadata = Data()
        uncryptedMetadata.append(metadata.data)
        uncryptedMetadata.append(Data(Array<UInt8>(repeating: 0x00, count: FirmwareCrypto.metadataBlockSize - metadata.data.count)))

        var paddedBinaryMetadata = Data()
        paddedBinaryMetadata.append(metadata.data)
        paddedBinaryMetadata.append(try Crypto.random(UInt(FirmwareCrypto.metadataBlockSize - metadata.data.count)))
        let encryptedMetadata = try Crypto.encrypt(paddedBinaryMetadata, key: key, initializationVector: initializationVector)

        var binary = Data()
        binary.append(uncryptedMetadata)
        binary.append(encryptedMetadata)
        binary.append(encryptedData)

        return binary
    }

    public static func decrypt(encryptedFirmware: Data, key: Data) throws -> (firmware: Data, metadata: Metadata) {
        if encryptedFirmware.count < (FirmwareCrypto.metadataBlockSize * 2) {
            throw LocalError.invalidFirmware
        }
        var index = 0
        let uncryptedMetadata = try Metadata(data: encryptedFirmware.subdata(in: index ..< (index + FirmwareCrypto.metadataBlockSize)))
        index += FirmwareCrypto.metadataBlockSize
        let initializationVector = uncryptedMetadata.initializationVector
        let encryptedMetadata = try Metadata(data: try Crypto.decrypt(encryptedFirmware.subdata(in: index ..< (index + FirmwareCrypto.metadataBlockSize)), key: key, initializationVector: initializationVector))
        index += FirmwareCrypto.metadataBlockSize
        if !uncryptedMetadata.isEqualTo(metadata: encryptedMetadata) {
            throw LocalError.invalidFirmware
        }
        let encryptedData = encryptedFirmware.subdata(in: index ..< encryptedFirmware.count)
        if Int(encryptedMetadata.length) > encryptedData.count {
            throw LocalError.invalidFirmware
        }
        if encryptedMetadata.encryptedHash != Crypto.sha1(encryptedData) {
            throw LocalError.invalidFirmware
        }
        let uncryptedData = try Crypto.decrypt(encryptedData, key: key, initializationVector: initializationVector)
        let data = uncryptedData.subdata(in: 0 ..< Int(uncryptedMetadata.length))
        if encryptedMetadata.uncryptedHash != Crypto.sha1(data) {
            throw LocalError.invalidFirmware
        }
        return (firmware: data, metadata: encryptedMetadata)
    }
    
}
