//
//  main.m
//  FireflyCrypto
//
//  Created by Denis Bohm on 2/12/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FDCrypto.h"
#import "FDIntelHex.h"

#include "fd_hal_aes.h"
#include "sha.h"

@interface FDFireflyCrypto : NSObject

- (void)main:(int)argc argv:(char * const [])argv;

@end

@implementation FDFireflyCrypto

- (NSData *)loadData:(NSString *)content
{
    NSArray *tokens = [content componentsSeparatedByString:@"0x"];
    NSMutableData *data = [NSMutableData data];
    for (NSUInteger i = 1; i < tokens.count; ++i) {
        NSString *token = tokens[i];
        char string[] = {[token characterAtIndex:0], [token characterAtIndex:1], '\0'};
        uint8_t byte = strtol(string, NULL, 16);
        [data appendBytes:&byte length:1];
    }
    return data;
}

- (NSString *)formatData:(NSData *)data
{
    NSMutableString *string = [NSMutableString string];
    uint8_t *bytes = (uint8_t *)data.bytes;
    for (NSUInteger i = 0; i < data.length; ++i) {
        [string appendFormat:@"%02x", bytes[i]];
    }
    return string;
}

- (NSData *)randomData:(NSUInteger)length
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (SecRandomCopyBytes(kSecRandomDefault, length, data.mutableBytes) != 0) {
        @throw [NSException exceptionWithName:@"CanNotGenerateRandomIV" reason:[NSString stringWithFormat:@"can not generate random IV (%d)", errno] userInfo:nil];
    }
    return data;
}

- (uint32_t)getHex:(NSString *)object
{
    NSScanner *scanner = [NSScanner scannerWithString:object];
    unsigned int value = 0;
    [scanner scanHexInt:&value];
    return value;
}

- (void)main:(int)argc argv:(char * const [])argv
{
    NSString *firmwarePath = @"firmware.hex";
    NSString *keyPath = @"key.h";
    NSString *encryptedFirmwarePath = @"encrypted_firmware.hex";
    bool zero = false;
    int c;
    while ((c = getopt(argc, argv, "zf:k:e:")) != -1) {
        switch (c) {
            case 'z': {
                zero = true;
            } break;
            case 'f': {
                firmwarePath = [[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] stringByStandardizingPath];
            } break;
            case 'k': {
                keyPath = [[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] stringByStandardizingPath];
            } break;
            case 'e': {
                encryptedFirmwarePath = [[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] stringByStandardizingPath];
            } break;
        }
    }
    NSString *keyContent = [NSString stringWithContentsOfFile:keyPath encoding:NSUTF8StringEncoding error:nil];
    NSData *key = [self loadData:keyContent];
    NSData *iv = zero ? [NSMutableData dataWithLength:16] : [self randomData:16];
    NSString *content = [NSString stringWithContentsOfFile:firmwarePath encoding:NSUTF8StringEncoding error:nil];
    if (content == nil) {
        @throw [NSException exceptionWithName:@"CanNotReadFirmware" reason:@"can not read firmware" userInfo:nil];
    }
    FDIntelHex *firmware = [FDIntelHex intelHex:content address:0 length:0];
    NSMutableData *data = [NSMutableData dataWithData:firmware.data];
#define BLOCK_SIZE 16
    NSUInteger padding = (BLOCK_SIZE - (data.length % BLOCK_SIZE)) % BLOCK_SIZE;
    if (padding > 0) {
        [data appendData:zero ? [NSMutableData dataWithLength:padding] : [self randomData:padding]];
    }
    NSData *encryptedData = [FDCrypto encrypt:key iv:iv data:data];
    FDIntelHex *encryptedFirmware = [[FDIntelHex alloc] init];
    encryptedFirmware.properties = [NSMutableDictionary dictionaryWithDictionary:firmware.properties];
    encryptedFirmware.properties[@"encrypted"] = @YES;
    encryptedFirmware.properties[@"length"] = [NSString stringWithFormat:@"0x%lx", (unsigned long)data.length];
    encryptedFirmware.properties[@"hash"] = [self formatData:[FDCrypto sha1:data]];
    encryptedFirmware.properties[@"cryptIV"] = [self formatData:iv];
    encryptedFirmware.properties[@"cryptHash"] = [self formatData:[FDCrypto sha1:encryptedData]];
    encryptedFirmware.data = encryptedData;
    NSString *encryptedContent = [encryptedFirmware format];
    NSError *error = nil;
    if (![encryptedContent writeToFile:encryptedFirmwarePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        @throw [NSException exceptionWithName:@"CanNotWriteFirmware" reason:[NSString stringWithFormat:@"can not write firmware (%@) to %@", error.description, encryptedFirmwarePath] userInfo:nil];
    }
    
    NSString *verifyContent = [NSString stringWithContentsOfFile:encryptedFirmwarePath encoding:NSUTF8StringEncoding error:&error];
    FDIntelHex *verifyFirmware = [FDIntelHex intelHex:verifyContent address:0 length:0];
    uint32_t verifyLength = [self getHex:verifyFirmware.properties[@"length"]];
    if (verifyLength != data.length) {
        @throw [NSException exceptionWithName:@"VerifyLengthFailure" reason:@"verify length failure" userInfo:nil];
    }
    NSString *verifyCryptHash = [self formatData:[FDCrypto sha1:verifyFirmware.data]];
    if (![verifyCryptHash isEqualToString:encryptedFirmware.properties[@"cryptHash"]]) {
        @throw [NSException exceptionWithName:@"VerifyHashFailure" reason:@"verify crypt hash failure" userInfo:nil];
    }

    NSMutableData *decrypted = [NSMutableData dataWithLength:verifyFirmware.data.length];
    fd_hal_aes_decrypt_t decrypt;
    fd_hal_aes_decrypt_start(&decrypt, key.bytes, iv.bytes);
    fd_hal_aes_decrypt_blocks(&decrypt, (uint8_t *)verifyFirmware.data.bytes, decrypted.mutableBytes, (uint32_t)verifyFirmware.data.length);
    if (memcmp(decrypted.bytes, data.bytes, data.length) != 0) {
        @throw [NSException exceptionWithName:@"VerifyDecryptFailure" reason:@"verify decrypt failure" userInfo:nil];
    }
    NSString *verifyHash = [self formatData:[FDCrypto sha1:decrypted]];
    if (![verifyHash isEqualToString:encryptedFirmware.properties[@"hash"]]) {
        @throw [NSException exceptionWithName:@"VerifyHashFailure" reason:@"verify hash failure" userInfo:nil];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        @try {
            FDFireflyCrypto *fireflyCrypto = [[FDFireflyCrypto alloc] init];
            [fireflyCrypto main:argc argv:(char * const *)argv];
            fprintf(stderr, "FireflyCrypto complete\n");
        } @catch (NSException *e) {
            fprintf(stderr, "unexpected exception: %s\n", [e.description UTF8String]);
        }
    }
    return 0;
}
