//
//  FDFireflyIceMint.m
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDFireflyIceMint.h"

#import <FireflyDevice/FDBinary.h>
#import <FireflyDevice/FDCrypto.h>
#import <FireflyDevice/FDIEEE754.h>
#import <FireflyDevice/FDIntelHex.h>

#import <FireflyProduction/FDExecutable.h>
#import <FireflyProduction/FDFireflyFlash.h>
#import <FireflyProduction/FDFireflyFlashNRF51.h>

@interface FDVersion : NSObject
@property uint16_t major;
@property uint16_t minor;
@property uint16_t patch;
@property uint32_t capabilities;
@property NSData *commit;
@end

@implementation FDVersion
@end

@implementation FDFireflyIceMint

//static uint8_t secretKey[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};

+ (uint32_t)getHexUInt32:(NSString *)hex
{
    if (hex) {
        NSScanner *scanner = [NSScanner scannerWithString:hex];
        unsigned int value = 0;
        if ([scanner scanHexInt:&value]) {
            return value;
        }
    }
    return 0;
}

- (FDVersion *)getVersion:(NSDictionary *)properties
{
    FDVersion *version = [[FDVersion alloc] init];
    version.major = [properties[@"major"] unsignedShortValue];
    version.major = [properties[@"minor"] unsignedShortValue];
    version.major = [properties[@"patch"] unsignedShortValue];
    version.capabilities = [FDFireflyIceMint getHexUInt32:properties[@"capabilities"]];
    NSString *s = properties[@"commit"];
    NSMutableData *commit = [NSMutableData data];
    if (s.length == 40) {
        for (int i = 0; i < 20; ++i) {
            unsigned value;
            NSScanner* scanner = [NSScanner scannerWithString:[s substringWithRange:NSMakeRange(i * 2, 2)]];
            [scanner scanHexInt:&value];
            uint8_t byte = value;
            [commit appendBytes:&byte length:1];
        }
    } else {
        commit.length = 20;
    }
    version.commit = commit;
    return version;
}

#define FD_VERSION_MAGIC 0xb001da1a

- (NSMutableData *)getMetadata:(FDIntelHex *)firmware
{
    FDBinary *binary = [[FDBinary alloc] init];
    
#if 1
    [binary putUInt32:FD_VERSION_MAGIC];
#endif
    
    // fd_version_binary_t
    [binary putUInt32:0]; // flags
    [binary putUInt32:(uint32_t)firmware.data.length];
    NSData *hash = [FDCrypto sha1:firmware.data];
    [binary putData:hash];
    [binary putData:hash];
    NSMutableData *iv = [NSMutableData data];
    iv.length = 16;
    [binary putData:iv];
    
#if 1
    // fd_version_revision_t
    FDVersion *version = [self getVersion:firmware.properties];
    [binary putUInt16:version.major]; // major
    [binary putUInt16:version.minor]; // minor
    [binary putUInt16:version.patch]; // patch
    [binary putUInt32:version.capabilities]; // capabilities
    [binary putData:version.commit]; // commit
#endif
    
    return [NSMutableData dataWithData:[binary dataValue]];
}

- (void)verify:(uint32_t)address data:(NSData *)data
{
    NSData *verify = [self.serialWireDebug readMemory:address length:(uint32_t)data.length];
    if (![data isEqualToData:verify]) {
        uint8_t *dataBytes = (uint8_t *)data.bytes;
        uint8_t *verifyBytes = (uint8_t *)verify.bytes;
        NSUInteger i;
        for (i = 0; i < data.length; ++i) {
            if (dataBytes[i] != verifyBytes[i]) {
                break;
            }
        }
        @throw [NSException exceptionWithName:@"verify issue"reason:
                [NSString stringWithFormat:@"verify issue at (%lu) 0x%08lx %02x != %02x", (unsigned long)i, address + i, dataBytes[i], verifyBytes[i]] userInfo:nil];
    }
}

+ (NSData *)loadConstants:(NSString *)name searchPath:(NSString *)searchPath
{
    NSString *path = [NSString stringWithFormat:@"%@/%@.txt", searchPath, name];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSMutableData *data = [NSMutableData data];
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ((line.length == 0) || [line hasPrefix:@"#"]) {
            continue;
        }
        float f = [line floatValue];
        uint16_t h = [FDIEEE754 floatToUint16:f];
        uint8_t bytes[] = {h, h >> 8};
        [data appendBytes:bytes length:sizeof(bytes)];
    }
    return data;
}

/*
- (void)mintCrypto
{
    FDLog(@"loading firmware update crypto key into flash...");
    NSMutableData *cryptoKey = [NSMutableData dataWithBytes:secretKey length:sizeof(secretKey)];
    cryptoKey.length = flash.pageSize;
    [flash writePages:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey erase:YES];
    [self verify:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey];
}
 */

/*
- (void)mintConstants
{
    NSString *constantsName = self.resources[@"constantsName"];
    if (constantsName.length > 0) {
        uint32_t constantsAddress = [self numberForKey:@"constantsAddress"];
        FDLog(@"loading 16-bit float %@ into flash at 0x%08x...", constantsName, constantsAddress);
        NSMutableData *constants = [NSMutableData dataWithData:[FDFireflyIceMint loadConstants:constantsName searchPath:searchPath]];
        constants.length = ((constants.length + flash.pageSize - 1) / flash.pageSize) * flash.pageSize;
        [flash writePages:constantsAddress data:constants erase:YES];
        [self verify:constantsAddress data:constants];
    }
}
 */

- (FDIntelHex *)loadIntelHex:(NSString *)path address:(uint32_t)address
{
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    return [FDIntelHex intelHex:content address:address length:0x40000 - address];
}

- (NSString *)getIntelHexPath:(NSString *)searchpath name:(NSString *)name
{
    NSString *path = [NSString stringWithFormat:@"%@/%@.hex", searchpath, name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    path = [NSString stringWithFormat:@"%@/release/%@.hex", searchpath, name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    path = [NSString stringWithFormat:@"%@/%@/%@_softdevice.hex", searchpath, name, name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    NSBundle *mainBundle = [NSBundle mainBundle];
    path = [mainBundle pathForResource:name ofType:@"hex"];
    if (path != nil) {
        return path;
    }
    NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
    path = [classBundle pathForResource:name ofType:@"hex"];
    if (path != nil) {
        return path;
    }
    @throw [NSException exceptionWithName:@"FirmwareUpdateFileNotFound" reason:@"firmware update file not found" userInfo:nil];
}

- (void)mint:(FDFireflyFlash *)flash firmware:(NSString *)firmwareKey
{
    NSDictionary *type = self.resources[firmwareKey];
    
    NSString *firmwareName = type[@"firmwareName"];
    if (firmwareName == nil) {
        return;
    }
    
    NSString *searchPath = self.resources[@"searchPath"];
    
    uint32_t firmwareAddress = [type[@"firmwareAddress"] unsignedIntValue];
    /*
    FDExecutable *firmware = [self readExecutable:firmwareName type:@"THUMB Flash Release" searchPath:searchPath address:firmwareAddress];
    FDExecutableSection *firmwareSection = firmware.sections[0];
     */
    NSString *path = [self getIntelHexPath:searchPath name:firmwareName];
    FDIntelHex *firmware = [self loadIntelHex:path address:firmwareAddress];
    NSInteger kb = (firmware.data.length + 1023) / 1024;
    NSMutableData *firmwareData = [NSMutableData dataWithData:firmware.data];
    NSInteger pages = (firmwareData.length + flash.pageSize - 1) / flash.pageSize;
    firmwareData.length = pages * flash.pageSize;
    FDLog(@"loading %@ (%dKB) into flash at 0x%08x...", firmwareName, kb, firmwareAddress);
    [flash writePages:firmwareAddress data:firmwareData erase:YES];
    [self verify:firmwareAddress data:firmware.data];
    
    if (type[@"metadataAddress"] == nil) {
        return;
    }
    
    NSMutableData *metadata = [self getMetadata:firmware];
    metadata.length = flash.pageSize;
    uint32_t metadataAddress = [type[@"metadataAddress"] unsignedIntValue];
    FDLog(@"loading %@ metadata into flash at 0x%08x", firmwareName, metadataAddress);
    [flash writePages:metadataAddress data:metadata erase:YES];
    [self verify:metadataAddress data:metadata];
}

#define UICR 0x10001000
#define BOOTLOADERADDR 0x014
#define UICR_BOOTLOADERADDR (UICR + BOOTLOADERADDR)

- (void)run
{
    FDLog(@"Mint Starting");
    
    NSString *processor = self.resources[@"processor"];
    FDLog(@"Loading FireflyFlash%@ into RAM...", processor);
    FDFireflyFlash *flash = [FDFireflyFlash fireflyFlash:processor];
    flash.searchPath = self.resources[@"searchPath"];
    flash.logger = self.logger;
    [flash initialize:self.serialWireDebug];
    
    FDLog(@"starting mass erase");
    [flash massErase];
    
    [self mint:flash firmware:@"bootloader"];
    [self mint:flash firmware:@"application"];
    [self mint:flash firmware:@"operatingSystem"];
    
#if 0
    // nRF51 series softdevice requires the bootloader address to be written to UICR->BOOTLOADERADDR -denis
    if ([processor isEqualToString:@"NRF51"]) {
        NSDictionary *bootloader = self.resources[@"bootloader"];
        NSString *bootloaderName = bootloader[@"firmwareName"];
        NSDictionary *operatingSystem = self.resources[@"operatingSystem"];
        NSString *operatingSystemName = operatingSystem[@"firmwareName"];
        if ((bootloaderName != nil) && (operatingSystemName != nil)) {
            uint32_t bootloaderAddress = [bootloader[@"firmwareAddress"] unsignedIntValue];
            FDLog(@"writing bootloader address 0x%08x to UICR->BOOTLOADERADDR", bootloaderAddress);
            NSMutableData *data = [NSMutableData dataWithData:[self.serialWireDebug readMemory:UICR length:flash.pageSize]];
            uint8_t *bytes = (uint8_t *)data.bytes;
            uint32_t index = BOOTLOADERADDR;
            bytes[index++] = bootloaderAddress;
            bytes[index++] = bootloaderAddress >> 8;
            bytes[index++] = bootloaderAddress >> 16;
            bytes[index++] = bootloaderAddress >> 24;
            [flash writePages:UICR data:data erase:NO];
            uint32_t verify = [self.serialWireDebug readMemory:UICR_BOOTLOADERADDR];
            if (verify != bootloaderAddress) {
                @throw [NSException exceptionWithName:@"verify issue" reason:[NSString stringWithFormat:@"verify issue at 0x%08x %08x != %08x", UICR_BOOTLOADERADDR, bootloaderAddress, verify] userInfo:nil];
            }
        }
    }
#endif
    
    FDLog(@"Reset & Run...");
    [self.serialWireDebug reset];
    [self.serialWireDebug run];
    
    FDLog(@"Mint Finished");
}

@end
