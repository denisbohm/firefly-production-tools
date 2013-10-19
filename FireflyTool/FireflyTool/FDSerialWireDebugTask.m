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

- (NSString *)getExecutablePath:(NSString *)name type:(NSString *)type
{
//    return [[NSBundle bundleForClass: [self class]] pathForResource:name ofType:@"elf"];
    return [NSString stringWithFormat:@"/Users/denis/sandbox/denisbohm/firefly-ice-firmware/%@/%@/%@.elf", type, name, name];
}

- (FDExecutable *)readExecutable:(NSString *)name type:(NSString *)type
{
    NSString *path = [self getExecutablePath:name type:type];
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:path];
    NSArray *sections = [executable combineSectionsType:FDExecutableSectionTypeProgram address:0 length:0x40000 pageSize:2048];
    executable.sections = sections;
    return executable;
}

- (FDExecutable *)readExecutable:(NSString *)name
{
    NSString *path = [self getExecutablePath:name type:@"THUMB RAM Debug"];
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

- (FDCortexM *)setupCortexRanges:(FDExecutable *)executable stackLength:(NSUInteger)stackLength heapLength:(NSUInteger)heapLength
{
    uint32_t ramStart = EFM32_RAM_ADDRESS;
    uint32_t ramLength = [_serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_RAM] * 1024;
    
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
    cortexM.stackRange.location = ramStart + ramLength - stackLength;
    cortexM.stackRange.length = stackLength;
    cortexM.heapRange.location = cortexM.stackRange.location - heapLength;
    cortexM.heapRange.length = heapLength;
    
    if (cortexM.heapRange.location < (cortexM.programRange.location + cortexM.programRange.length)) {
        @throw [NSException exceptionWithName:@"CORTEXOUTOFRAM" reason:@"Cortex out of RAM" userInfo:nil];
    }
    
    // remap vector table to program start in RAM
    [self.serialWireDebug writeMemory:SCB_VTOR value:ramStart];

    return cortexM;
}

@end
