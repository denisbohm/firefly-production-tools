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

- (void)initialize:(FDSerialWireDebug *)serialWireDebug;

- (void)disableWatchdogByErasingIfNeeded;

- (void)massErase;

- (void)program:(FDExecutable *)executable;

@end
