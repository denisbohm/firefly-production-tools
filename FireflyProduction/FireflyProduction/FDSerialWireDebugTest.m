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
#define SIZEOF_INT16 2

@implementation FDSerialWireDebugTest

- (void)loadExecutable:(NSString *)name
{
    NSString *processor = self.resources[@"processor"];
    FDFireflyFlash *flash = [FDFireflyFlash fireflyFlash:processor];
    [flash initialize:self.serialWireDebug];
    [flash disableWatchdogByErasingIfNeeded];
    
    NSString *searchPath = self.resources[@"searchPath"];
    self.executable = [self readExecutable:name searchPath:searchPath];
    [self writeExecutableIntoRam:self.executable];
    self.cortexM = [self setupCortexRanges:self.executable stackLength:512 heapLength:128];
    FDExecutableFunction *halt = self.executable.functions[@"halt"];
    self.cortexM.breakLocation = halt.address;
    
    /*
    NSDictionary *globals = self.executable.globals;
    NSArray *types = @[@"data", @"text", @"fast", @"rodata"];
    for (NSString *type in types) {
        FDExecutableSymbol *loadStart = globals[[NSString stringWithFormat:@"__%@_load_start__", type]];
        FDExecutableSymbol *start = globals[[NSString stringWithFormat:@"__%@_start__", type]];
        FDExecutableSymbol *end = globals[[NSString stringWithFormat:@"__%@_end__", type]];
        NSLog(@"memory_copy 0x%08x 0x%08x 0x%08x", loadStart.address, start.address, end.address);
    }
     */
}

- (uint32_t)functionAddress:(NSString *)name
{
    FDExecutableFunction *function = _executable.functions[name];
    if (function == nil) {
        @throw [NSException exceptionWithName:@"UnknownFunction"
                                       reason:[NSString stringWithFormat:@"unknown function %@", name]
                                     userInfo:nil];
    }
    if (function.address == 0) {
        @throw [NSException exceptionWithName:@"MissingFunction"
                                       reason:[NSString stringWithFormat:@"missing function %@", name]
                                     userInfo:nil];
    }
    return function.address;
}

- (uint32_t)run:(NSString *)name r0:(uint32_t)r0 r1:(uint32_t)r1
{
    return [self.cortexM run:[self functionAddress:name] r0:r0 r1:r1 timeout:5.0];
}

- (uint32_t)run:(NSString *)name
{
    return [self run:name r0:0 r1:0];
}

- (void)start:(NSString *)name
{
    [self.cortexM start:[self functionAddress:name] r0:0 r1:0 r2:0 r3:0];
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
    uint32_t value = [self run:@"GPIO_PinInGet" r0:port r1:pin];
    return value ? YES : NO;
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

- (void)getInt16:(int16_t *)v count:(NSUInteger)count
{
    uint32_t a = self.cortexM.heapRange.location;
    for (NSUInteger i = 0; i < count; ++i) {
        NSData *data = [self.cortexM.serialWireDebug readMemory:a length:4];
        uint8_t *buffer = (uint8_t *)data.bytes;
        int16_t f = [FDBinary unpackUInt16:buffer];
        v[i] = f;
        a += SIZEOF_INT16;
    }
}

- (void)invoke:(NSString *)name ix:(int16_t *)x iy:(int16_t *)y iz:(int16_t *)z
{
    uint32_t a = self.cortexM.heapRange.location;
    [self invoke:name r0:a r1:a + SIZEOF_INT16 r2:a + 2 * SIZEOF_INT16];
    int16_t v[3];
    [self getInt16:v count:3];
    *x = v[0];
    *y = v[1];
    *z = v[2];
    FDLog(@"%@ x = 0x%04x, y = 0x%04x, z = 0x%04x", name, *x, *y, *z);
}

- (void)getFloat:(float *)v count:(NSUInteger)count
{
    uint32_t a = self.cortexM.heapRange.location;
    for (NSUInteger i = 0; i < count; ++i) {
        NSData *data = [self.cortexM.serialWireDebug readMemory:a length:4];
        uint8_t *buffer = (uint8_t *)data.bytes;
        float f = [FDBinary unpackFloat32:buffer];
        v[i] = f;
        a += SIZEOF_FLOAT;
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
