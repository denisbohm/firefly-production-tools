//
//  main.m
//  FireflyCrypto
//
//  Created by Denis Bohm on 2/12/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <FireflyDevice/FireflyDevice.h>

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

- (void)main:(int)argc argv:(char * const [])argv
{
    NSString *firmwarePath = @"firmware.hex";
    NSString *keyPath = @"key.h";
    NSString *encryptedFirmwarePath = @"encrypted_firmware.hex";
    int c;
    while ((c = getopt(argc, argv, "f:k:e:")) != -1) {
        switch (c) {
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
    NSData *iv = [self randomData:20];
    NSString *content = [NSString stringWithContentsOfFile:firmwarePath encoding:NSUTF8StringEncoding error:nil];
    if (content == nil) {
        @throw [NSException exceptionWithName:@"CanNotReadFirmware" reason:@"can not read firmware" userInfo:nil];
    }
    FDIntelHex *firmware = [FDIntelHex intelHex:content address:0 length:0];
    NSMutableData *data = [NSMutableData dataWithData:firmware.data];
    NSUInteger padding = (16 - (data.length % 16)) % 16;
    if (padding > 0) {
        [data appendData:[self randomData:padding]];
    }
    NSData *encryptedData = [FDCrypto encrypt:key iv:iv data:data];
    FDIntelHex *encryptedFirmware = [[FDIntelHex alloc] init];
    encryptedFirmware.properties = [NSMutableDictionary dictionaryWithDictionary:firmware.properties];
    encryptedFirmware.properties[@"encrypted"] = @YES;
    encryptedFirmware.properties[@"length"] = [NSNumber numberWithInteger:data.length];
    encryptedFirmware.properties[@"hash"] = [self formatData:[FDCrypto hash:data]];
    encryptedFirmware.properties[@"cryptIV"] = [self formatData:iv];
    encryptedFirmware.properties[@"cryptHash"] = [self formatData:[FDCrypto hash:encryptedData]];
    encryptedFirmware.data = encryptedData;
    NSString *encryptedContent = [encryptedFirmware format];
    NSError *error = nil;
    if (![encryptedFirmwarePath writeToFile:encryptedContent atomically:NO encoding:NSUTF8StringEncoding error:&error]) {
        @throw [NSException exceptionWithName:@"CanNotWriteFirmware" reason:@"can not write firmware" userInfo:nil];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        @try {
            FDFireflyCrypto *fireflyCrypto = [[FDFireflyCrypto alloc] init];
            [fireflyCrypto main:argc argv:(char * const *)argv];
        } @catch (NSException *e) {
            fprintf(stderr, "unexpected exception: %s\n", [e.description UTF8String]);
        }
    }
    return 0;
}
