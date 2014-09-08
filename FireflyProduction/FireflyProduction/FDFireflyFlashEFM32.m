//
//  FDFireflyFlashEFM32.m
//  FireflyProduction
//
//  Created by Denis Bohm on 8/20/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashEFM32.h"

#import <ARMSerialWireDebug/FDEFM32.h>

@implementation FDFireflyFlashEFM32

- (void)setupProcessor
{
    _family = [self.serialWireDebug readMemoryUInt8:EFM32_PART_FAMILY];
    
    _flashSize = [self.serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_FLASH] * 1024;
    
    uint8_t mem_info_page_size = [self.serialWireDebug readMemoryUInt8:EFM32_MEM_INFO_PAGE_SIZE];
    self.pageSize = 1 << ((mem_info_page_size + 10) & 0xff);
    
    self.ramAddress = EFM32_RAM_ADDRESS;
    self.ramSize = [self.serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_RAM] * 1024;
}

- (void)feedWatchdog
{
    [self.serialWireDebug writeMemory:EFM32_WDOG_CMD value:EFM32_WDOG_CMD_CLEAR];
}

- (BOOL)disableWatchdogByErasingIfNeeded
{
    uint32_t wdogCtrl = [self.serialWireDebug readMemory:EFM32_WDOG_CTRL];
    if ((wdogCtrl & EFM32_WDOG_CTRL_LOCK) == 0) {
        [self.serialWireDebug writeMemory:EFM32_WDOG_CTRL value:EFM32_WDOG_CTRL_DEFAULT];
        return NO;
    }
    
    if ((wdogCtrl & EFM32_WDOG_CTRL_EN) == 0) {
        return NO;
    }
    
    FDLog(@"watchdog is enabled and locked - erasing and resetting device to clear watchdog");
    [self massErase];
    [self reset];
    wdogCtrl = [self.serialWireDebug readMemory:EFM32_WDOG_CTRL];
    if (wdogCtrl & EFM32_WDOG_CTRL_EN) {
        FDLog(@"could not disable watchdog");
    }
    
    [self loadFireflyFlashFirmwareIntoRAM];
    
    return YES;
}

- (void)massErase
{
    switch (_family) {
        case 0: {
            UInt32 pages = _flashSize / self.pageSize;
            for (UInt32 page = 0; page < pages; ++page) {
                UInt32 address = page * self.pageSize;
                [self.serialWireDebug erase:address];
            }
        } break;
        case EFM32_PART_FAMILY_Gecko: {
            UInt32 pages = _flashSize / self.pageSize;
            for (UInt32 page = 0; page < pages; ++page) {
                UInt32 address = page * self.pageSize;
                [self.serialWireDebug writeMemory:EFM32_WDOG_CMD value:EFM32_WDOG_CMD_CLEAR];
                [self.serialWireDebug erase:address];
            }
        } break;
        case EFM32_PART_FAMILY_Leopard_Gecko: {
            [self.serialWireDebug massErase];
        } break;
        default:
            @throw [NSException exceptionWithName:@"UnknownFamily" reason:@"unknown family" userInfo:nil];
    }
}

- (void)setDebugLock
{
    uint8_t bytes[] = {0, 0, 0, 0};
    [self.serialWireDebug flash:EFM32_LB_DLW data:[NSData dataWithBytes:bytes length:4]];
}

- (BOOL)debugLock
{
    uint32_t value = [self.serialWireDebug readMemory:EFM32_LB_DLW];
    return (value & 0x0000000f) != 0x0000000f;
}

@end
