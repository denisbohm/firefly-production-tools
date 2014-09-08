//
//  FDFireflyFlash.h
//  FireflyProduction
//
//  Created by Denis Bohm on 7/22/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDExecutable.h"

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

@interface FDFireflyFlash : NSObject

+ (FDFireflyFlash *)fireflyFlash:(NSString *)processor;

@property FDCortexM *cortexM;
@property FDSerialWireDebug *serialWireDebug;
@property FDLogger *logger;

@property NSString *processor;
@property NSString *searchPath;

@property uint32_t pageSize;
@property uint32_t ramAddress;
@property uint32_t ramSize;

- (void)initialize:(FDSerialWireDebug *)serialWireDebug;

- (BOOL)disableWatchdogByErasingIfNeeded;

- (void)massErase;
- (void)reset;

- (void)writePages:(uint32_t)address data:(NSData *)data;
- (void)writePages:(uint32_t)address data:(NSData *)data erase:(BOOL)erase;
- (void)program:(FDExecutable *)executable;

- (void)setDebugLock;
- (BOOL)debugLock;

// for use by subclasses
- (void)loadFireflyFlashFirmwareIntoRAM;

@end
