//
//  Crypto.h
//  FireflyFirmwareCrypto
//
//  Created by Denis Bohm on 4/13/17.
//  Copyright © 2017 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Crypto : NSObject

+ (nullable NSData *)random:(NSUInteger)count error:(NSError * __nullable * __null_unspecified)error;

+ (nonnull NSData *)sha1:(nonnull NSData *)data;

+ (nullable NSData *)encrypt:(nonnull NSData *)data key:(nonnull NSData *)key initializationVector:(nonnull NSData *)initializationVector error:(NSError * __nullable * __null_unspecified)error;

+ (nullable NSData *)decrypt:(nonnull NSData *)data key:(nonnull NSData *)key initializationVector:(nonnull NSData *)initializationVector error:(NSError * __nullable * __null_unspecified)error;

@end
