//
//  FDGdbServerSwd.m
//  Sync
//
//  Created by Denis Bohm on 4/28/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDGdbServerSwd.h"

/* reg-arm.dat
 name:arm
 xmlarch:arm
 expedite:r11,sp,pc
 32:r0
 32:r1
 32:r2
 32:r3
 32:r4
 32:r5
 32:r6
 32:r7
 32:r8
 32:r9
 32:r10
 32:r11
 32:r12
 32:sp
 32:lr
 32:pc
 96:f0
 96:f1
 96:f2
 96:f3
 96:f4
 96:f5
 96:f6
 96:f7
 32:fps
 32:cpsr
 */

typedef struct {
    NSInteger gdbNumber;
    NSInteger swdNumber;
    NSInteger bits;
    char *name;
} reg_t;

static
reg_t generalRegisters[] = {
    {0, 0, 32, "r0"},
    {1, 1, 32, "r1"},
    {2, 2, 32, "r2"},
    {3, 3, 32, "r3"},
    {4, 4, 32, "r4"},
    {5, 5, 32, "r5"},
    {6, 6, 32, "r6"},
    {7, 7, 32, "r7"},
    {8, 8, 32, "r8"},
    {9, 9, 32, "r9"},
    {10 ,10, 32, "r10"},
    {11, 11, 32, "r11"},
    {12, 12, 32, "r12"},
    {13, 13, 32, "sp"},
    {14, 14, 32, "lr"},
    {15, 15, 32, "pc"},
    {16, -1, 96, "f0"},
    {17, -1, 96, "f1"},
    {18, -1, 96, "f2"},
    {19, -1, 96, "f3"},
    {20, -1, 96, "f4"},
    {21, -1, 96, "f5"},
    {22, -1, 96, "f6"},
    {23, -1, 96, "f7"},
    {24, -1, 32, "fps"},
    {25, 16, 32, "xpsr"},
};

static
reg_t expediteRegisters[] = {
//    {11, 11, 32, "r11"},
//    {13, 13, 32, "sp"},
//    {15, 15, 32, "pc"},
};

@interface FDGdbServerSwd ()

@property NSUInteger generalRegisterCount;
@property NSUInteger expediteRegisterCount;
@property uint8_t signal;
@property NSMutableDictionary *transfers;
@property BOOL killed;

@end

@implementation FDGdbServerSwd

- (id)init
{
    if (self = [super init]) {
        _generalRegisterCount = sizeof(generalRegisters) / sizeof(reg_t);
        _expediteRegisterCount = sizeof(expediteRegisters) / sizeof(reg_t);
        _signal = 5; // TRAP
        _transfers = [NSMutableDictionary dictionary];
        NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
        NSStringEncoding encoding;
        for (NSString *name in @[@"memory-map"]) {
            NSString *file = [mainBundle pathForResource:name ofType:@"xml"];
            NSString *string = [NSString stringWithContentsOfFile:file usedEncoding:&encoding error:nil];
            [_transfers setObject:string forKey:name];
        }
    }
    return self;
}

- (void)gdbConnected
{
    _killed = NO;
    
    uint32_t breakpointCount = [_serialWireDebug breakpointCount];
    for (uint32_t i = 0; i < breakpointCount; ++i) {
        [_serialWireDebug disableBreakpoint:i];
    }
    [_serialWireDebug enableBreakpoints:true];
}

- (void)notifyStop
{
    NSMutableString *response = [NSMutableString stringWithFormat:@"Stop:T%02x", _signal];
    for (NSUInteger i = 0; i < _expediteRegisterCount; ++i) {
        if (i > 0) {
            [response appendString:@";"];
        }
        reg_t reg = expediteRegisters[i];
        uint32_t value = [_serialWireDebug readRegister:reg.swdNumber];
        [response appendFormat:@"%02x:%08x", (unsigned int)reg.gdbNumber, (uint32_t)value];
    }
    [_gdbServer notify:response];
}

- (void)gdbServerReportStopReason:(NSData *)packet
{
    if (_killed) {
        _killed = false;
        [_gdbServer respond:@"OK"];
        return;
    }
    [_gdbServer respond:[NSString stringWithFormat:@"S%02x", _signal]];
}

- (void)gdbInterrupt
{
    [_serialWireDebug halt];
    NSLog(@"gdbInterrupt %@", [_serialWireDebug isHalted] ? @"halted" : @"running");
    [_gdbServer respond:[NSString stringWithFormat:@"T%02x", _signal]];
}

- (void)gdbServerKill:(NSData *)packet
{
    [_serialWireDebug halt];
    [_serialWireDebug reset];
    _killed = YES;
}

- (void)gdbServerContinue:(NSData *)packet
{
    uint32_t breakpointCount = [_serialWireDebug breakpointCount];
    for (uint32_t i = 0; i < breakpointCount; ++i) {
        uint32_t address;
        if ([_serialWireDebug getBreakpoint:i address:&address]) {
            NSLog(@"gdbServerContinue breakpoint at 0x%08x", address);
        }
    }
    [_serialWireDebug run];
    NSLog(@"gdbServerContinue %@", [_serialWireDebug isHalted] ? @"halted" : @"running");
}

- (void)gdbServerStep:(NSData *)packet
{
    [_serialWireDebug step];
    NSLog(@"gdbServerStep %@", [_serialWireDebug isHalted] ? @"halted" : @"running");
    [_gdbServer respond:[NSString stringWithFormat:@"T%02x", _signal]];
}

// z0,addr,kind
- (void)gdbServerSetPoints:(NSData *)packet {
    NSScanner *scanner = [NSScanner scannerWithString:[[NSString alloc] initWithData:packet encoding:NSASCIIStringEncoding]];
    [scanner setScanLocation:3]; // skip 'z0,'
    unsigned int address;
    [scanner scanHexInt:&address];
    scanner.scanLocation += 1; // skip ','
    unsigned int kind;
    [scanner scanHexInt:&kind];
    
    NSInteger free = -1;
    NSMutableArray *breakpoints = [NSMutableArray array];
    uint32_t breakpointCount = [_serialWireDebug breakpointCount];
    for (uint32_t i = 0; i < breakpointCount; ++i) {
        uint32_t breakpointAddress;
        if ([_serialWireDebug getBreakpoint:i address:&breakpointAddress]) {
            [breakpoints addObject:[NSNumber numberWithLong:breakpointAddress]];
        } else
        if (free == -1) {
            free = i;
        }
    }
    if ([breakpoints containsObject:[NSNumber numberWithLong:address]]) {
        // breakpoint already set
        [_gdbServer respond:@"OK"];
    } else
    if (free != -1) {
        // new breakpoint
        [_serialWireDebug setBreakpoint:(uint32_t)free address:address];
        NSLog(@"added hardware breakpoint %ld", free);
        [_gdbServer respond:@"OK"];
    } else {
        // no hardware breakpoints left
        [_gdbServer respond:@"E00"];
    }
}

// Z0,addr,kind
- (void)gdbServerClearPoints:(NSData *)packet {
    NSScanner *scanner = [NSScanner scannerWithString:[[NSString alloc] initWithData:packet encoding:NSASCIIStringEncoding]];
    [scanner setScanLocation:3]; // skip 'Z0,'
    unsigned int address;
    [scanner scanHexInt:&address];
    scanner.scanLocation += 1; // skip ','
    unsigned int kind;
    [scanner scanHexInt:&kind];
    
    uint32_t breakpointCount = [_serialWireDebug breakpointCount];
    for (uint32_t i = 0; i < breakpointCount; ++i) {
        uint32_t breakpointAddress;
        if ([_serialWireDebug getBreakpoint:i address:&breakpointAddress]) {
            if (address == breakpointAddress) {
                [_serialWireDebug disableBreakpoint:i];
                NSLog(@"removed hardware breakpoint %u", i);
            }
        }
    }
    [_gdbServer respond:@"OK"];
}

- (void)gdbServerDetach:(NSData *)packet
{
    [_gdbServer respond:@"OK"];
}

- (void)gdbServerReadRegisters:(NSData *)packet
{
    NSMutableString *response = [NSMutableString string];
    for (NSUInteger i = 0; i < _generalRegisterCount; ++i) {
        reg_t reg = generalRegisters[i];
        if (reg.swdNumber >= 0) {
            uint32_t value = [_serialWireDebug readRegister:(uint16_t)reg.swdNumber];
            [response appendFormat:@"%08x", CFSwapInt32(value)];
        } else {
            for (NSUInteger j = 0; j < (reg.bits / 4); ++j) {
                [response appendString:@"x"];
            }
        }
    }
    [_gdbServer respond:response];
}

- (void)gdbServerWriteRegisters:(NSData *)packet
{
    [_gdbServer respond:@"E00"];
}

// ‘p n’
- (void)gdbServerReadRegister:(NSData *)packet
{
    NSScanner *scanner = [NSScanner scannerWithString:[[NSString alloc] initWithData:packet encoding:NSASCIIStringEncoding]];
    [scanner setScanLocation:1]; // skip 'p'
    unsigned int index;
    [scanner scanHexInt:&index];
    if (index < _generalRegisterCount) {
        reg_t reg = generalRegisters[index];
        uint32_t value = [_serialWireDebug readRegister:reg.swdNumber];
        [_gdbServer respond:[NSString stringWithFormat:@"%08x", CFSwapInt32(value)]];
    } else {
        [_gdbServer respond:@"E00"];
    }
}

// ‘P n...=r...’
- (void)gdbServerWriteRegister:(NSData *)packet
{
    NSScanner *scanner = [NSScanner scannerWithString:[[NSString alloc] initWithData:packet encoding:NSASCIIStringEncoding]];
    [scanner setScanLocation:1]; // skip 'p'
    unsigned int index;
    [scanner scanHexInt:&index];
    scanner.scanLocation += 1; // skip '='
    unsigned int value;
    [scanner scanHexInt:&value];
    if (index < _generalRegisterCount) {
        reg_t reg = generalRegisters[index];
        uint32_t v = CFSwapInt32(value);
        NSLog(@"set register %ld = %08x", (long)reg.swdNumber, v);
        [_serialWireDebug writeRegister:reg.swdNumber value:v];
        [_gdbServer respond:@"OK"];
    } else {
        [_gdbServer respond:@"E00"];
    }
}

// ‘m addr,length’
- (void)gdbServerReadMemory:(NSData *)packet
{
    NSScanner *scanner = [NSScanner scannerWithString:[[NSString alloc] initWithData:packet encoding:NSASCIIStringEncoding]];
    [scanner setScanLocation:1]; // skip 'm'
    unsigned int address;
    [scanner scanHexInt:&address];
    scanner.scanLocation += 1; // skip ','
    unsigned int length;
    [scanner scanHexInt:&length];
    
    if (address > 0x20007fff) {
        [_gdbServer respond:@""];
        return;
    }
    
    NSData *data = [_serialWireDebug readMemory:(uint32_t)address length:(uint32_t)length];
    uint8_t *bytes = (uint8_t *)data.bytes;
    NSMutableString *response = [NSMutableString string];
    for (NSUInteger i = 0; i < data.length; ++i) {
        uint8_t byte = bytes[i];
        [response appendFormat:@"%02x", byte];
    }
    [_gdbServer respond:response];
}

/*
// ‘M addr,length:XX...’
- (void)gdbServerWriteMemory:(NSData *)packet
{
}
*/

- (void)gdbServerReportOffsets:(NSData *)packet
{
    [_gdbServer respond:@"Text=0;Data=0;Bss=0"];
}

- (void)gdbServerReportSupported:(NSData *)packet
{
    NSMutableString *response = [NSMutableString stringWithString:@"PacketSize=3fff"];
    for (NSString *name in [_transfers allKeys]) {
        [response appendFormat:@";qXfer:%@:read+", name];
    }
    [_gdbServer respond:response];
}

- (void)gdbServerTransfer:(NSData *)packet
{
    NSArray *tokens = [[[NSString alloc] initWithData:packet encoding:NSASCIIStringEncoding] componentsSeparatedByString:@":"];
    NSString *key = [tokens objectAtIndex:1];
    NSString *response = _transfers[key];
    [_gdbServer respond:response];
}

- (void)gdbServerRequestSymbols:(NSData *)packet
{
    [_gdbServer respond:@"OK"];
}

@end
