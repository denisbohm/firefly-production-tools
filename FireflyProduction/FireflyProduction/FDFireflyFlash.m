//
//  FDFireflyFlash.m
//  FireflyProduction
//
//  Created by Denis Bohm on 7/22/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDExecutable.h"
#import "FDFireflyFlash.h"

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

#define FIREFLY_FLASH_STACK_LENGTH 128

@interface FDFireflyFlash ()

@property FDExecutable *fireflyFlashExecutable;
@property uint32_t fireflyFlashProgramEnd;

@end

@implementation FDFireflyFlash

+ (FDFireflyFlash *)fireflyFlash:(NSString *)processor
{
    NSString *className = [NSString stringWithFormat:@"FDFireflyFlash%@", processor];
    Class class = NSClassFromString(className);
    FDFireflyFlash *fireflyFlash = [[class alloc] init];
    fireflyFlash.processor = processor;
    return fireflyFlash;
}

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
    }
    return self;
}

- (void)setupProcessor
{
    @throw [NSException exceptionWithName:@"unimplemented" reason:@"unimplemented" userInfo:nil];
}

- (void)massErase
{
    @throw [NSException exceptionWithName:@"UnknownFamily" reason:@"unknown family" userInfo:nil];
}

- (BOOL)disableWatchdogByErasingIfNeeded
{
    return NO;
}

- (void)feedWatchdog
{
}

- (void)setDebugLock
{
}

- (BOOL)debugLock
{
    return NO;
}

// See the firefly-ice-firmware project in github for source code to generate the FireflyFlash elf files. -denis
- (void)loadFireflyFlashFirmwareIntoRAM
{
    NSString *flashResource = [NSString stringWithFormat:@"FireflyFlash%@", _processor];
    NSString *path = [NSString stringWithFormat:@"%@/THUMB RAM Debug/%@.elf", _searchPath, flashResource];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [[NSBundle mainBundle] pathForResource:flashResource ofType:@"elf"];
        if (path == nil) {
            path = [[NSBundle bundleForClass:[self class]] pathForResource:flashResource ofType:@"elf"];
        }
    }
    _fireflyFlashExecutable = [[FDExecutable alloc] init];
    [_fireflyFlashExecutable load:path];
    _fireflyFlashExecutable.sections = [_fireflyFlashExecutable combineAllSectionsType:FDExecutableSectionTypeProgram address:_ramAddress length:_ramSize pageSize:4];

    for (FDExecutableSection *section in _fireflyFlashExecutable.sections) {
        switch (section.type) {
            case FDExecutableSectionTypeData:
            case FDExecutableSectionTypeProgram: {
                [_serialWireDebug writeMemory:section.address data:section.data];
                uint32_t end = section.address + (uint32_t)section.data.length;
                if (end > _fireflyFlashProgramEnd) {
                    _fireflyFlashProgramEnd = end;
                }
            } break;
        }
    }
}

- (void)setupCortexM
{
    _cortexM = [[FDCortexM alloc] init];
    _cortexM.serialWireDebug = _serialWireDebug;
    _cortexM.logger.consumer = _logger.consumer;
    
    uint32_t programLength = _fireflyFlashProgramEnd - _ramAddress;
    
    _cortexM.programRange.location = _ramAddress;
    _cortexM.programRange.length = programLength;
    _cortexM.stackRange.location = _ramAddress + programLength;
    _cortexM.stackRange.length = FIREFLY_FLASH_STACK_LENGTH;
    _cortexM.heapRange.location = _ramAddress + programLength + FIREFLY_FLASH_STACK_LENGTH;
    _cortexM.heapRange.length = _ramSize - programLength - FIREFLY_FLASH_STACK_LENGTH;
    _pagesPerWrite = _cortexM.heapRange.length / _pageSize;
    
    FDExecutableFunction *haltFunction = _fireflyFlashExecutable.functions[@"halt"];
    _cortexM.breakLocation = haltFunction.address;
}

- (void)reset
{
    [self massErase];
    [_serialWireDebug reset];
    [_serialWireDebug run];
    [NSThread sleepForTimeInterval:0.001];
    [_serialWireDebug halt];
}

- (void)initialize:(FDSerialWireDebug *)serialWireDebug
{
    _serialWireDebug = serialWireDebug;
    _logger = _serialWireDebug.logger;
    [self setupProcessor];
    [self loadFireflyFlashFirmwareIntoRAM];
    [self setupCortexM];
}

- (void)writePages:(uint32_t)address data:(NSData *)data
{
    [self writePages:address data:data erase:NO];
}

- (void)writePages:(uint32_t)address data:(NSData *)data erase:(BOOL)erase
{
    FDExecutableFunction *writePagesFunction = _fireflyFlashExecutable.functions[@"write_pages"];
    uint32_t offset = 0;
    while (offset < data.length) {
        uint32_t length = (uint32_t) (data.length - offset);
        uint32_t pages = length / _pageSize;
        if (pages > _pagesPerWrite) {
            pages = _pagesPerWrite;
            length = pages * _pageSize;
        }
        NSData *subdata = [data subdataWithRange:NSMakeRange(offset, length)];
        [_serialWireDebug writeMemory:_cortexM.heapRange.location data:subdata];
        [self feedWatchdog];
        [_cortexM run:writePagesFunction.address r0:address r1:_cortexM.heapRange.location r2:pages r3:erase ? 1 : 0 timeout:5];
        offset += length;
        address += length;
    }
}

- (void)program:(FDExecutable *)executable
{
    [_serialWireDebug halt];

    NSArray *sections = [executable combineSectionsType:FDExecutableSectionTypeProgram address:0 length:_ramAddress pageSize:_pageSize];
    for (FDExecutableSection *section in sections) {
        switch (section.type) {
            case FDExecutableSectionTypeData:
                break;
            case FDExecutableSectionTypeProgram: {
                if (section.address >= _ramAddress) {
                    FDLog(@"ignoring RAM data for address 0x%08x length %lu", section.address, (unsigned long)section.data.length);
                    continue;
                }
//                FDLog(@"writing flash at 0x%08x length %lu", section.address, (unsigned long)section.data.length);
                [self writePages:section.address data:section.data];
// slower method using SWD only (no flash function required in RAM -denis
//                [_serialWireDebug program:section.address data:section.data];
                NSData *verify = [_serialWireDebug readMemory:section.address length:(uint32_t)section.data.length];
                if (![section.data isEqualToData:verify]) {
                    FDLog(@"write verification failed!");
                    @throw [NSException exceptionWithName:@"FlashVerificationFailure" reason:@"flash verification failure" userInfo:nil];
                }
            } break;
        }
    }
}

@end
