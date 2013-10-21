//
//  FDSerialWireDebugTest.m
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDSerialWireDebugTest.h"

#import <FireflyDevice/FDBinary.h>

#import <FireflyProduction/FDFireflyFlash.h>

#define SIZEOF_FLOAT 4

@implementation FDSerialWireDebugTest

- (void)loadExecutable:(NSString *)name
{
    [self clearInterrupts];
    
    FDFireflyFlash *flash = [[FDFireflyFlash alloc] init];
    [flash initialize:self.serialWireDebug];
    [flash disableWatchdogByErasingIfNeeded];
    
    self.executable = [self readExecutable:name];
    [self writeExecutableIntoRam:self.executable];
    self.cortexM = [self setupCortexRanges:self.executable stackLength:256 heapLength:128];
    FDExecutableFunction *halt = self.executable.functions[@"halt"];
    self.cortexM.breakLocation = halt.address;
}

- (uint32_t)run:(NSString *)name r0:(uint32_t)r0 r1:(uint32_t)r1
{
    FDExecutableFunction *function = _executable.functions[name];
    return [self.cortexM run:function.address r0:r0 r1:r1 timeout:5.0];
}

- (uint32_t)run:(NSString *)name
{
    return [self run:name r0:0 r1:0];
}

- (void)GPIO_PinOutClear:(uint32_t)port pin:(uint32_t)pin
{
    [self run:@"GPIO_PinOutClear" r0:port r1:pin];
}

- (void)GPIO_PinOutSet:(uint32_t)port pin:(uint32_t)pin
{
    [self run:@"GPIO_PinOutSet" r0:port r1:pin];
}

- (bool)GPIO_PinInGet:(uint32_t)port pin:(uint32_t)pin
{
    return [self run:@"GPIO_PinInGet" r0:port r1:pin] ? YES : NO;
}

- (uint32_t)fd_log_get_count
{
    return [self run:@"fd_log_get_count" r0:0 r1:0];
}

- (uint32_t)invoke:(NSString *)name r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2
{
    uint32_t logCountBefore = [self fd_log_get_count];
    
    FDExecutableFunction *function = _executable.functions[name];
    if (function == nil) {
        @throw [NSException exceptionWithName:@"UnknownFunction"
                                       reason:[NSString stringWithFormat:@"unknown function %@", name]
                                     userInfo:nil];
    }
    uint32_t result = [self.cortexM run:function.address r0:r0 r1:r1 r2:r2 timeout:5.0];
    
    uint32_t logCountAfter = [self fd_log_get_count];
    uint32_t logCount = logCountAfter - logCountBefore;
    if (logCount > 0) {
        uint32_t address = [self run:@"fd_log_get_message"];
        NSData *data = [self.serialWireDebug readMemory:address length:128];
        NSString *message = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        @throw [NSException exceptionWithName:@"AssertionFailures"
                                       reason:[NSString stringWithFormat:@"%d assertions failed during %@ (first message: %@)", logCount, name, message]
                                     userInfo:nil];
    }
    return result;
}

- (uint32_t)invoke:(NSString *)name r0:(uint32_t)r0 r1:(uint32_t)r1
{
    return [self invoke:name r0:r0 r1:r1 r2:0];
}

- (uint32_t)invoke:(NSString *)name r0:(uint32_t)r0
{
    return [self invoke:name r0:r0 r1:0 r2:0];
}

- (uint32_t)invoke:(NSString *)name
{
    return [self invoke:name r0:0 r1:0 r2:0];
}

- (void)getFloat:(float *)v count:(NSUInteger)count
{
    uint32_t a = self.cortexM.heapRange.location;
    for (NSUInteger i = 0; i < count; ++i) {
        NSData *data = [self.cortexM.serialWireDebug readMemory:a length:4];
        uint8_t *buffer = (uint8_t *)data.bytes;
        float f = [FDBinary unpackFloat32:buffer];
        v[i] = f;
        a += 4;
    }
}

- (void)invoke:(NSString *)name x:(float *)x y:(float *)y z:(float *)z
{
    uint32_t a = self.cortexM.heapRange.location;
    [self invoke:name r0:a r1:a + SIZEOF_FLOAT r2:a + 2 * SIZEOF_FLOAT];
    float v[3];
    [self getFloat:v count:3];
    *x = v[0];
    *y = v[1];
    *z = v[2];
    FDLog(@"%@ x = %f, y = %f, z = %f", name, *x, *y, *z);
}

- (float)toFloat:(uint32_t)v
{
    return [FDBinary unpackFloat32:(uint8_t *)&v];
}

@end
