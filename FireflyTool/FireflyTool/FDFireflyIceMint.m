//
//  FDFireflyIceMint.m
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDFireflyIceMint.h"

#import <FireflyDeviceFramework/FDBinary.h>
#import <FireflyDeviceFramework/FDCrypto.h>

#import <FireflyProduction/FDExecutable.h>
#import <FireflyProduction/FDFireflyFlash.h>

@interface FDFireflyIceMint ()

@end

@implementation FDFireflyIceMint

static uint8_t secretKey[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};

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

#define FD_UPDATE_BOOT_ADDRESS 0x0000
#define FD_UPDATE_CRYPTO_ADDRESS 0x7000
#define FD_UPDATE_METADATA_ADDRESS 0x7800
#define FD_UPDATE_FIRMWARE_ADDRESS 0x8000

#define FD_UPDATE_DATA_BASE_ADDRESS 0x00000000

- (void)verify:(uint32_t)address data:(NSData *)data
{
    NSData *verify = [self.serialWireDebug readMemory:address length:(uint32_t)data.length];
    if (![data isEqualToData:verify]) {
        @throw [NSException exceptionWithName:@"verify issue"reason:@"verify issue" userInfo:nil];
    }
}

- (void)run
{
    FDLog(@"Mint Starting");
    
    FDLog(@"Loading FireflyFlash into RAM...");
    FDFireflyFlash *flash = [[FDFireflyFlash alloc] init];
    flash.logger = self.logger;
    [flash initialize:self.serialWireDebug];
    
    FDLog(@"loading FireflyBoot info flash...");
    FDExecutable *fireflyBoot = [self readExecutable:@"FireflyBoot" type:@"THUMB Flash Release"];
    FDExecutableSection *fireflyBootSection = fireflyBoot.sections[0];
    [flash writePages:FD_UPDATE_BOOT_ADDRESS data:fireflyBootSection.data erase:YES];
    [self verify:FD_UPDATE_BOOT_ADDRESS data:fireflyBootSection.data];
    
    FDLog(@"loading firmware update crypto key into flash...");
    NSMutableData *cryptoKey = [NSMutableData dataWithBytes:secretKey length:sizeof(secretKey)];
    cryptoKey.length = flash.pageSize;
    [flash writePages:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey erase:YES];
    [self verify:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey];
    
    FDLog(@"loading firmware metadata into flash");
    FDExecutable *fireflyIce = [self readExecutable:@"FireflyIce" type:@"THUMB Flash Release"];
    FDExecutableSection *fireflyIceSection = fireflyIce.sections[0];
    NSMutableData *metadata = [self getMetadata:fireflyIceSection.data];
    metadata.length = flash.pageSize;
    [flash writePages:FD_UPDATE_METADATA_ADDRESS data:metadata erase:YES];
    [self verify:FD_UPDATE_METADATA_ADDRESS data:metadata];
    
    FDLog(@"loading firmware into flash...");
    [flash writePages:FD_UPDATE_FIRMWARE_ADDRESS data:fireflyIceSection.data erase:YES];
    [self verify:FD_UPDATE_FIRMWARE_ADDRESS data:fireflyIceSection.data];
    
    FDLog(@"Reset & Run...");
    [self.serialWireDebug reset];
    [self.serialWireDebug run];
    
    FDLog(@"Mint Finished");
}

@end
