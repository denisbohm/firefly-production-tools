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
#import <ARMSerialWireDebug/FDEFM32.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

#define FIREFLY_FLASH_STACK_LENGTH 128

@interface FDFireflyFlash ()

@property FDExecutable *fireflyFlashExecutable;
@property uint32_t fireflyFlashProgramEnd;
@property uint8_t family;
@property uint32_t flashSize;
@property uint32_t ramSize;
@property uint32_t pageSize;
@property uint32_t pagesPerWrite;

@end

@implementation FDFireflyFlash

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
    }
    return self;
}

- (void)loadFireflyFlashFirmwareIntoRAM
{
//    NSString *path = @"/Users/denis/sandbox/denisbohm/firefly-ice-firmware/THUMB RAM Debug/FireflyFlash.elf";
    // See the firefly-ice-firmware project in github for source code to generate the FireflyFlash.elf -denis
    NSString *path = [[NSBundle bundleForClass: [self class]] pathForResource:@"FireflyFlash" ofType:@"elf"];
    _fireflyFlashExecutable = [[FDExecutable alloc] init];
    [_fireflyFlashExecutable load:path];
    _fireflyFlashExecutable.sections = [_fireflyFlashExecutable combineAllSectionsType:FDExecutableSectionTypeProgram address:0x20000000 length:0x8000 pageSize:4];

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
    
    _family = [_serialWireDebug readMemoryUInt8:EFM32_PART_FAMILY];

    _flashSize = [_serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_FLASH] * 1024;
    
    uint8_t mem_info_page_size = [_serialWireDebug readMemoryUInt8:EFM32_MEM_INFO_PAGE_SIZE];
    _pageSize = 1 << ((mem_info_page_size + 10) & 0xff);
    
    _ramSize = [_serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_RAM] * 1024;
    
    uint32_t programLength = _fireflyFlashProgramEnd - EFM32_RAM_ADDRESS;
    
    _cortexM.programRange.location = EFM32_RAM_ADDRESS;
    _cortexM.programRange.length = programLength;
    _cortexM.stackRange.location = EFM32_RAM_ADDRESS + programLength;
    _cortexM.stackRange.length = FIREFLY_FLASH_STACK_LENGTH;
    _cortexM.heapRange.location = EFM32_RAM_ADDRESS + programLength + FIREFLY_FLASH_STACK_LENGTH;
    _cortexM.heapRange.length = _ramSize - programLength - FIREFLY_FLASH_STACK_LENGTH;
    _pagesPerWrite = _cortexM.heapRange.length / _pageSize;
    
    FDExecutableFunction *haltFunction = _fireflyFlashExecutable.functions[@"halt"];
    _cortexM.breakLocation = haltFunction.address;
}

- (BOOL)disableWatchdogByErasingIfNeeded
{
    uint32_t wdogCtrl = [_serialWireDebug readMemory:EFM32_WDOG_CTRL];
    if ((wdogCtrl & EFM32_WDOG_CTRL_LOCK) == 0) {
        [_serialWireDebug writeMemory:EFM32_WDOG_CTRL value:EFM32_WDOG_CTRL_DEFAULT];
        return NO;
    }
    
    if ((wdogCtrl & EFM32_WDOG_CTRL_EN) == 0) {
        return NO;
    }
    
    FDLog(@"watchdog is enabled and locked - erasing and resetting device to clear watchdog");
    [self massErase];
    [_serialWireDebug reset];
    [_serialWireDebug run];
    [NSThread sleepForTimeInterval:0.001];
    [_serialWireDebug halt];
    wdogCtrl = [_serialWireDebug readMemory:EFM32_WDOG_CTRL];
    if (wdogCtrl & EFM32_WDOG_CTRL_EN) {
        FDLog(@"could not disable watchdog");
    }
    return YES;
}

- (void)initialize:(FDSerialWireDebug *)serialWireDebug
{
    _serialWireDebug = serialWireDebug;
    
    _logger = _serialWireDebug.logger;
    
    [self loadFireflyFlashFirmwareIntoRAM];
    [self setupCortexM];
}

- (void)massErase
{
    switch (_family) {
        case EFM32_PART_FAMILY_Gecko: {
            UInt32 pages = _flashSize / _pageSize;
            for (UInt32 page = 0; page < pages; ++page) {
                UInt32 address = page * _pageSize;
                [_serialWireDebug writeMemory:EFM32_WDOG_CMD value:EFM32_WDOG_CMD_CLEAR];
                [_serialWireDebug erase:address];
            }
        } break;
        case EFM32_PART_FAMILY_Leopard_Gecko: {
            [_serialWireDebug massErase];
        } break;
        default:
            @throw [NSException exceptionWithName:@"UnknownFamily" reason:@"unknown family" userInfo:nil];
    }
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
        [_serialWireDebug writeMemory:EFM32_WDOG_CMD value:EFM32_WDOG_CMD_CLEAR];
        [_cortexM run:writePagesFunction.address r0:address r1:_cortexM.heapRange.location r2:pages r3:erase ? 1 : 0 timeout:5];
        offset += length;
        address += length;
    }
}

- (void)program:(FDExecutable *)executable
{
    [_serialWireDebug halt];

    NSArray *sections = [executable combineSectionsType:FDExecutableSectionTypeProgram address:0 length:EFM32_RAM_ADDRESS pageSize:_pageSize];
    for (FDExecutableSection *section in sections) {
        switch (section.type) {
            case FDExecutableSectionTypeData:
                break;
            case FDExecutableSectionTypeProgram: {
                if (section.address >= EFM32_RAM_ADDRESS) {
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

- (void)setDebugLock
{
    uint8_t bytes[] = {0, 0, 0, 0};
    [_serialWireDebug flash:EFM32_LB_DLW data:[NSData dataWithBytes:bytes length:4]];
}

- (BOOL)debugLock
{
    uint32_t value = [_serialWireDebug readMemory:EFM32_LB_DLW];
    return (value & 0x0000000f) != 0x0000000f;
}

@end
