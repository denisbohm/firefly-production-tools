//
//  FDSerialWireDebugTask.m
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDSerialWireDebugTask.h"

#import <ARMSerialWireDebug/FDSerialEngine.h>
#import <ARMSerialWireDebug/FDEFM32.h>

#define SCS_BASE (0xE000E000)
#define SCB_BASE (SCS_BASE +  0x0D00)
#define SCB_VTOR (SCB_BASE + 0x8)

#define SCB_AIRCR 0xE000ED0C
#define SCB_AIRCR_VECTKEY 0x05FA0000
#define SCB_AIRCR_VECTRESET 0x00000001

@implementation FDSerialWireDebugTask

- (void)run
{
}

- (void)hardReset
{
    [_serialWireDebug setGpioReset:true];
    [_serialWireDebug.serialEngine write];
    [NSThread sleepForTimeInterval:0.001];
    [_serialWireDebug setGpioReset:false];
    [_serialWireDebug.serialEngine write];
    [NSThread sleepForTimeInterval:0.100];
}

- (void)clearInterrupts
{
    [self.serialWireDebug halt];
    [self.serialWireDebug reset];
    // In "fresh" microcontrollers there seems to be interrupts pending, maybe due to preloaded boot loader?
    // The following resets everything except the debug interface.
    [self.serialWireDebug writeMemory:SCB_AIRCR value:SCB_AIRCR_VECTKEY | SCB_AIRCR_VECTRESET];
    [self.serialWireDebug step];
}

- (NSString *)getExecutablePath:(NSString *)name type:(NSString *)type searchPath:(NSString *)searchPath
{
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@.elf", searchPath, type, name, name];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:NO]) {
        return path;
    }
    path = [NSString stringWithFormat:@"%@/%@ THUMB Release/%@.elf", searchPath, name, name];
    if ([fileManager fileExistsAtPath:path isDirectory:NO]) {
        return path;
    }
    path = [NSString stringWithFormat:@"%@/%@ THUMB Debug/%@.elf", searchPath, name, name];
    if ([fileManager fileExistsAtPath:path isDirectory:NO]) {
        return path;
    }
    path = [NSString stringWithFormat:@"%@/%@.elf", searchPath, name];
    if ([fileManager fileExistsAtPath:path isDirectory:NO]) {
        return path;
    }
    return [[NSBundle bundleForClass: [self class]] pathForResource:name ofType:@"elf"];
}

- (FDExecutable *)readExecutable:(NSString *)name type:(NSString *)type searchPath:(NSString *)searchPath address:(uint32_t)address
{
    NSString *path = [self getExecutablePath:name type:type searchPath:searchPath];
    if (path == nil) {
        @throw [NSException exceptionWithName:@"ExecutableNotFound" reason:[NSString stringWithFormat:@"executable not found: %@", name] userInfo:nil];
    }
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:path];
    NSArray *sections = [executable combineSectionsType:FDExecutableSectionTypeProgram address:address length:0x40000 pageSize:2048];
    executable.sections = sections;
    return executable;
}

- (FDExecutable *)readExecutable:(NSString *)name searchPath:(NSString *)searchPath
{
    NSString *path = [self getExecutablePath:name type:@"THUMB RAM Debug" searchPath:searchPath];
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:path];
    executable.sections = [executable combineAllSectionsType:FDExecutableSectionTypeProgram address:0x20000000 length:0x8000 pageSize:4];
    return executable;
}

- (void)writeExecutableIntoRam:(FDExecutable *)executable
{
    NSMutableData *data = [NSMutableData data];
    for (int i = 0; i < 0x4000; ++i) {
        uint8_t byte = 0;
        [data appendBytes:&byte length:1];
    }
    [self.serialWireDebug writeMemory:0x20000000 data:data];
    @try {
        for (FDExecutableSection *section in executable.sections) {
            switch (section.type) {
                case FDExecutableSectionTypeData:
                case FDExecutableSectionTypeProgram:
                    [self.serialWireDebug writeMemory:section.address data:section.data];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"load exception: %@", e);
    }
}

- (uint32_t)numberForKey:(NSString *)key
{
    NSNumber *number = self.resources[key];
    return (uint32_t)[number unsignedLongLongValue];
}

- (BOOL)boolForKey:(NSString *)key
{
    NSNumber *number = self.resources[key];
    return [number boolValue];
}

- (FDCortexM *)setupCortexRanges:(FDExecutable *)executable stackLength:(NSUInteger)stackLength heapLength:(NSUInteger)heapLength
{
    uint32_t ramStart = EFM32_RAM_ADDRESS;
    uint32_t ramLength;
    NSString *processor = self.resources[@"processor"];
    BOOL useEFM32RamSizeRegister = [@"EFM32" isEqualToString:processor];
    if (useEFM32RamSizeRegister) {
        ramLength = [_serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_RAM] * 1024;
    } else {
        ramLength = [self numberForKey:@"ramSize"];
    }
    
    uint32_t programAddressEnd = ramStart;
    for (FDExecutableSection *section in executable.sections) {
        switch (section.type) {
            case FDExecutableSectionTypeData:
            case FDExecutableSectionTypeProgram: {
                uint32_t sectionAddressEnd = (uint32_t)(section.address + section.data.length);
                if (sectionAddressEnd > programAddressEnd) {
                    programAddressEnd = sectionAddressEnd;
                }
            } break;
        }
    }
    uint32_t programLength = programAddressEnd - ramStart;
    
    FDCortexM *cortexM = [[FDCortexM alloc] init];
    cortexM.logger = self.logger;
    cortexM.serialWireDebug = self.serialWireDebug;
    
    cortexM.programRange.location = ramStart;
    cortexM.programRange.length = programLength;
    cortexM.stackRange.location = (UInt32)(ramStart + ramLength - stackLength);
    cortexM.stackRange.length = (UInt32)stackLength;
    cortexM.heapRange.location = (UInt32)(cortexM.stackRange.location - heapLength);
    cortexM.heapRange.length = (UInt32)heapLength;
    
    if (cortexM.heapRange.location < (cortexM.programRange.location + cortexM.programRange.length)) {
        @throw [NSException exceptionWithName:@"CORTEXOUTOFRAM" reason:@"Cortex out of RAM" userInfo:nil];
    }
    
    // remap vector table to program start in RAM
    [self.serialWireDebug writeMemory:SCB_VTOR value:ramStart];

    return cortexM;
}

@end
