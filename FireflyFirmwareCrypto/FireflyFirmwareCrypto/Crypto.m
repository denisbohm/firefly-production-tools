//
//  Crypto.m
//  FireflyFirmwareCrypto
//
//  Created by Denis Bohm on 4/13/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

#import "Crypto.h"

#include <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>

@interface Crypto ()
@end

@implementation Crypto

+ (nullable NSData *)random:(NSUInteger)count error:(NSError * __nullable * __null_unspecified)error
{
    NSMutableData *data = [NSMutableData dataWithLength:count];
    if (SecRandomCopyBytes(kSecRandomDefault, count, data.mutableBytes) != 0) {
        *error = [NSError errorWithDomain:@"Crypto" code:1 userInfo:nil];
        return nil;
    }
    return data;
}

+ (nonnull NSData *)sha1:(nonnull NSData *)data
{
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}

+ (nullable NSData *)encrypt:(nonnull NSData *)data key:(nonnull NSData *)key initializationVector:(nonnull NSData *)initializationVector error:(NSError * __nullable * __null_unspecified)error
{
    NSMutableData *out = [NSMutableData dataWithLength:data.length];
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                          kCCAlgorithmAES128, 0,
                                          key.bytes, kCCKeySizeAES128,
                                          initializationVector.bytes,
                                          data.bytes, data.length,
                                          out.mutableBytes, out.length,
                                          &numBytesEncrypted);
    if (cryptStatus != kCCSuccess) {
        *error = [NSError errorWithDomain:@"Crypto" code:2 userInfo:nil];
        return nil;
    }
    return out;
}

+ (nullable NSData *)decrypt:(nonnull NSData *)data key:(nonnull NSData *)key initializationVector:(nonnull NSData *)initializationVector error:(NSError * __nullable * __null_unspecified)error
{
    NSMutableData *out = [NSMutableData dataWithLength:data.length];
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                          kCCAlgorithmAES128, 0,
                                          key.bytes, kCCKeySizeAES128,
                                          initializationVector.bytes,
                                          data.bytes, data.length,
                                          out.mutableBytes, out.length,
                                          &numBytesEncrypted);
    if (cryptStatus != kCCSuccess) {
        *error = [NSError errorWithDomain:@"Crypto" code:3 userInfo:nil];
        return nil;
    }
    return out;
}

@end
