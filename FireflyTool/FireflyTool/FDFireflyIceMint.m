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
    
    NSString *searchPath = self.resources[@"searchPath"];

    NSString *bootName = self.resources[@"bootName"];
    FDLog(@"loading %@ info flash...", bootName);
    uint32_t bootAddress = [self numberForKey:@"bootAddress"];
    FDExecutable *fireflyBoot = [self readExecutable:bootName type:@"THUMB Flash Release" searchPath:searchPath address:bootAddress];
    FDExecutableSection *fireflyBootSection = fireflyBoot.sections[0];
    [flash writePages:bootAddress data:fireflyBootSection.data erase:YES];
    [self verify:bootAddress data:fireflyBootSection.data];
    
    /*
    FDLog(@"loading firmware update crypto key into flash...");
    NSMutableData *cryptoKey = [NSMutableData dataWithBytes:secretKey length:sizeof(secretKey)];
    cryptoKey.length = flash.pageSize;
    [flash writePages:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey erase:YES];
    [self verify:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey];
     */
    
    NSString *firmwareName = self.resources[@"firmwareName"];
    FDLog(@"loading %@ metadata into flash", firmwareName);
    uint32_t firmwareAddress = [self numberForKey:@"firmwareAddress"];
    FDExecutable *fireflyIce = [self readExecutable:firmwareName type:@"THUMB Flash Release" searchPath:searchPath address:firmwareAddress];
    FDExecutableSection *fireflyIceSection = fireflyIce.sections[0];
    NSMutableData *metadata = [self getMetadata:fireflyIceSection.data];
    metadata.length = flash.pageSize;
    uint32_t metadataAddress = [self numberForKey:@"metadataAddress"];
    [flash writePages:metadataAddress data:metadata erase:YES];
    [self verify:metadataAddress data:metadata];
    
    FDLog(@"loading %@ into flash...", firmwareName);
    [flash writePages:firmwareAddress data:fireflyIceSection.data erase:YES];
    [self verify:firmwareAddress data:fireflyIceSection.data];
    
    NSString *constantsName = self.resources[@"constants"];
    if (constantsName.length > 0) {
        uint32_t constantsAddress = [self numberForKey:@"constantsAddress"];
        FDLog(@"loading 16-bit float %@ into flash...", constantsName);
        NSMutableData *constants = [NSMutableData dataWithData:[FDFireflyIceMint loadConstants:constantsName searchPath:searchPath]];
        constants.length = ((constants.length + flash.pageSize - 1) / flash.pageSize) * flash.pageSize;
        [flash writePages:constantsAddress data:constants erase:YES];
        [self verify:constantsAddress data:constants];
    }
    
    FDLog(@"Reset & Run...");
    [self.serialWireDebug reset];
    [self.serialWireDebug run];
    
    FDLog(@"Mint Finished");
}

@end
