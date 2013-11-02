//
//  FDFireflyFlash.h
//  FireflyProduction
//
//  Created by Denis Bohm on 7/22/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

@interface FDFireflyFlash : NSObject

@property FDCortexM *cortexM;
@property FDSerialWireDebug *serialWireDebug;
@property FDLogger *logger;

@property NSString *flashResource;

@property uint8_t family;
@property uint32_t flashSize;
@property uint32_t pageSize;
@property uint32_t ramSize;

- (void)initialize:(FDSerialWireDebug *)serialWireDebug;
- (void)configure:(FDSerialWireDebug *)serialWireDebug;

- (BOOL)disableWatchdogByErasingIfNeeded;

- (void)massErase;
- (void)reset;

- (void)writePages:(uint32_t)address data:(NSData *)data;
- (void)writePages:(uint32_t)address data:(NSData *)data erase:(BOOL)erase;
- (void)program:(FDExecutable *)executable;

- (void)setDebugLock;
- (BOOL)debugLock;

@end
