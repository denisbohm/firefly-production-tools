//
//  FDSerialWireDebugTask.h
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <FireflyProduction/FDExecutable.h>

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

#import <Foundation/Foundation.h>

@interface FDSerialWireDebugTask : NSObject

@property FDLogger *logger;
@property NSDictionary *resources;
@property FDSerialWireDebug *serialWireDebug;
@property FDCortexM *cortexM;

- (FDExecutable *)readExecutable:(NSString *)name;
- (FDExecutable *)readExecutable:(NSString *)name type:(NSString *)type;
- (void)writeExecutableIntoRam:(FDExecutable *)executable;
- (FDCortexM *)setupCortexRanges:(FDExecutable *)executable stackLength:(NSUInteger)stackLength heapLength:(NSUInteger)heapLength;
- (void)clearInterrupts;

- (void)run;

@end
