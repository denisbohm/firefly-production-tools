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

#import <FireflyProduction/FDExecutable.h>
#import <FireflyProduction/FDFireflyFlash.h>

@interface FDFireflyIceMint ()

@end

@implementation FDFireflyIceMint

//static uint8_t secretKey[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};

- (NSMutableData *)getMetadata:(NSData *)data
{
    NSData *hash = [FDCrypto sha1:data];
    FDBinary *binary = [[FDBinary alloc] init];
    [binary putUInt32:0]; // flags
    [binary putUInt32:(uint32_t)data.length];
    [binary putData:hash];
    [binary putData:hash];
    NSMutableData *iv = [NSMutableData data];
    iv.length = 16;
    [binary putData:iv];
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
        @throw [NSException exceptionWithName:@"verify issue"reason:[NSString stringWithFormat:@"verify issue at %lu %02x != %02x", (unsigned long)i, dataBytes[i], verifyBytes[i]] userInfo:nil];
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

- (void)mint:(FDFireflyFlash *)flash firmware:(NSString *)firmwareKey
{
    NSDictionary *type = self.resources[firmwareKey];
    
    NSString *firmwareName = type[@"firmwareName"];
    if (firmwareName == nil) {
        return;
    }
    
    NSString *searchPath = self.resources[@"searchPath"];
    
    uint32_t firmwareAddress = [type[@"firmwareAddress"] unsignedIntValue];
    FDExecutable *firmware = [self readExecutable:firmwareName type:@"THUMB Flash Release" searchPath:searchPath address:firmwareAddress];
    FDExecutableSection *firmwareSection = firmware.sections[0];
    NSInteger kb = (firmwareSection.data.length + 1023) / 1024;
    FDLog(@"loading %@ (%dKB) into flash at 0x%08x...", firmwareName, kb, firmwareAddress);
    [flash writePages:firmwareAddress data:firmwareSection.data erase:YES];
    [self verify:firmwareAddress data:firmwareSection.data];

    if (type[@"metadataAddress"] == nil) {
        return;
    }
    
    NSMutableData *metadata = [self getMetadata:firmwareSection.data];
    metadata.length = flash.pageSize;
    uint32_t metadataAddress = [type[@"metadataAddress"] unsignedIntValue];
    FDLog(@"loading %@ metadata into flash at 0x%08x", firmwareName, metadataAddress);
    [flash writePages:metadataAddress data:metadata erase:YES];
    [self verify:metadataAddress data:metadata];
}

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
    
    // nRF51 series softdevice requires the bootloader address to be written to UICR->BOOTLOADERADDR -denis
    if ([processor isEqualToString:@"NRF51"]) {
        NSDictionary *bootloader = self.resources[@"bootloader"];
        NSString *bootloaderName = bootloader[@"firmwareName"];
        NSDictionary *operatingSystem = self.resources[@"operatingSystem"];
        NSString *operatingSystemName = operatingSystem[@"firmwareName"];
        if ((bootloaderName != nil) && (operatingSystemName != nil)) {
            uint32_t bootloaderAddress = [bootloader[@"firmwareAddress"] unsignedIntValue];
#define UICR 0x10001000
#define BOOTLOADERADDR 0x014
#define UICR_BOOTLOADERADDR (UICR + BOOTLOADERADDR)
            FDLog(@"writing bootloader address 0x%08x to UICR->BOOTLOADERADDR", bootloaderAddress);
            [self.serialWireDebug writeMemory:UICR_BOOTLOADERADDR value:bootloaderAddress];
        }
    }
    
    FDLog(@"Reset & Run...");
    [self.serialWireDebug reset];
    [self.serialWireDebug run];
    
    FDLog(@"Mint Finished");
}

@end
