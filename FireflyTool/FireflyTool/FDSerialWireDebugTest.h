//
//  FDSerialWireDebugTest.h
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#include "FDSerialWireDebugTask.h"

#import <FireflyProduction/FDExecutable.h>

#import <Foundation/Foundation.h>

@interface FDSerialWireDebugTest : FDSerialWireDebugTask

@property FDExecutable *executable;

- (void)loadExecutable:(NSString *)name;
- (uint32_t)run:(NSString *)name r0:(uint32_t)r0 r1:(uint32_t)r1;
- (uint32_t)run:(NSString *)name;
- (void)GPIO_PinOutClear:(uint32_t)port pin:(uint32_t)pin;
- (void)GPIO_PinOutSet:(uint32_t)port pin:(uint32_t)pin;
- (uint32_t)invoke:(NSString *)name r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2;
- (uint32_t)invoke:(NSString *)name r0:(uint32_t)r0 r1:(uint32_t)r1;
- (uint32_t)invoke:(NSString *)name r0:(uint32_t)r0;
- (uint32_t)invoke:(NSString *)name;
- (float)toFloat:(uint32_t)v;
- (void)getFloat:(float *)v count:(NSUInteger)count;
- (void)invoke:(NSString *)name x:(float *)x y:(float *)y z:(float *)z;

@end
