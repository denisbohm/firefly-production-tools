//
//  FirmwareCryptoCommand.swift
//  FireflyFirmwareCrypto
//
//  Created by Denis Bohm on 4/15/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

import Cocoa

open class FirmwareCryptoCommand: NSObject {

    public enum LocalError: Error {
        case missingArgument
        case invalidArgument(String)
    }

    open func parseVersion(iterator: inout IndexingIterator<[String]>) throws -> FirmwareCrypto.Version {
        let major = try parseUInt32(iterator: &iterator)
        let minor = try parseUInt32(iterator: &iterator)
        let revision = try parseUInt32(iterator: &iterator)
        let commit = try parseHex(iterator: &iterator, count: 20)
        return FirmwareCrypto.Version(major: major, minor: minor, revision: revision, commit: commit)
    }

    open func parseUInt32(iterator: inout IndexingIterator<[String]>) throws -> UInt32 {
        guard let string = iterator.next() else {
            throw LocalError.missingArgument
        }
        guard let value = UInt32(string) else {
            throw LocalError.invalidArgument(string)
        }
        return value
    }

    open func parseFile(iterator: inout IndexingIterator<[String]>) throws -> String {
        guard let string = iterator.next() else {
            throw LocalError.missingArgument
        }

        return string
    }

    open func parseHex(iterator: inout IndexingIterator<[String]>, count: Int) throws -> Data {
        guard let string = iterator.next() else {
            throw LocalError.missingArgument
        }

        let characters = Array(string.utf8)
        if characters.count != (count * 2) {
            throw LocalError.invalidArgument(string)
        }
        var bytes: [UInt8] = []
        var index = 0
        for _ in 0 ..< count {
            let nibble1 = try IntelHexParser.parseHex(character: characters[index])
            index += 1
            let nibble0 = try IntelHexParser.parseHex(character: characters[index])
            index += 1
            let byte = UInt8((nibble1 << 4) | nibble0)
            bytes.append(byte)
        }
        return Data(bytes: bytes)
    }

    open func printUsage() {
        print("usage:")
        print("  -firmware <input firmware file (IntelHex)>")
        print("  -encrypted-firmware <output encrypted firmware file (binary)>")
        print("  -key <encryption key (16 hex bytes>")
        print("  -version <major (UInt32)> <minor (UInt32)> <revision (UInt32)> <commit (20 hex bytes)>")
        print("  -decrypt (decrypt instead of the default which is encrypt)")
        print("  -? -usage -help (print this help text)")
        print()
        print("encrypted firmware consists of three blocks:")
        print("  clear metadata binary block (1KB)")
        print("  encrypted metadata binary block (1KB)")
        print("  encrypted firmware data binary block (variable size)")
        print()
        print("metadata binary is little endian:")
        print("  flags: UInt32")
        print("  version major: UInt32")
        print("  version minor: UInt32")
        print("  version revision: UInt32")
        print("  version commit: UInt8[20]")
        print("  address: UInt32")
        print("  length: UInt32")
        print("  initialization vector: UInt8[16]")
        print("  encrypted firmware data SHA1: UInt8[20]")
        print("  unencrypted firmware data SHA1: UInt8[20]")
    }

    open func encrypt(firmwarePath: String, encryptedFirmwarePath: String, key: Data, version: FirmwareCrypto.Version) throws {
        let firmware = try String(contentsOfFile: firmwarePath, encoding: String.Encoding.utf8)
        let binary = try FirmwareCrypto.encrypt(firmware: firmware, key: key, version: version)
        try binary.write(to: URL(fileURLWithPath: encryptedFirmwarePath))
    }

    open func decrypt(firmwarePath: String, encryptedFirmwarePath: String, key: Data) throws {
        let encryptedFirmware = try Data(contentsOf: URL(fileURLWithPath: encryptedFirmwarePath))
        let (firmware, metadata) = try FirmwareCrypto.decrypt(encryptedFirmware: encryptedFirmware, key: key)
        let intelHex = IntelHex(data: firmware, address: metadata.address)
        let content = try IntelHexFormatter.format(intelHex: intelHex)
        try content.write(to: URL(fileURLWithPath: firmwarePath), atomically: false, encoding: .utf8)
        let version = metadata.version
        var commit = ""
        for byte in version.commit {
            commit += String(format: "%02X", byte)
        }
        print("version \(version.major) \(version.minor) \(version.revision) \(commit)")
    }

    open func run(arguments: [String]) throws {
        if arguments.isEmpty {
            printUsage()
            return
        }

        var firmwarePath = "firmware.hex"
        var encryptedFirmwarePath = "encrypted-firmware.bin"
        var key = Data(bytes: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0xef])
        var version = FirmwareCrypto.Version(major: 0, minor: 0, revision: 0, commit: Data(Array<UInt8>(repeating: 0x00, count: 20)))

        var iterator = arguments.makeIterator()
        let _ = iterator.next() // skip command path
        while let arg = iterator.next() {
            switch arg {
            case "-firmware":
                firmwarePath = try parseFile(iterator: &iterator)
            case "-encrypted-firmware":
                encryptedFirmwarePath = try parseFile(iterator: &iterator)
            case "-key":
                key = try parseHex(iterator: &iterator, count: 16)
            case "-version":
                version = try parseVersion(iterator: &iterator)
            case "-decrypt":
                try decrypt(firmwarePath: firmwarePath, encryptedFirmwarePath: encryptedFirmwarePath, key: key)
                return
            case "-?", "-usage", "-help":
                printUsage()
                return
            default:
                throw LocalError.invalidArgument(arg)
            }
        }

        try encrypt(firmwarePath: firmwarePath, encryptedFirmwarePath: encryptedFirmwarePath, key: key, version: version)
    }

    open func main(arguments: [String]) -> Int32 {
        do {
            try run(arguments: arguments)
            return 0
        } catch {
            print("exception: \(error.localizedDescription)")
            printUsage()
            return 1
        }
    }
    
}
