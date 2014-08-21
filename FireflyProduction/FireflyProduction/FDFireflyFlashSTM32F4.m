//
//  FDFireflyFlashSTM32F4.m
//  FireflyProduction
//
//  Created by Denis Bohm on 8/20/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashSTM32F4.h"

@implementation FDFireflyFlashSTM32F4

- (void)setupProcessor
{
    self.pageSize = 2048;
    
    self.ramAddress = 0x20000000;
    self.ramSize = 65536;
}

#define PERIPH_BASE           ((uint32_t)0x40000000)
#define AHB1PERIPH_BASE       (PERIPH_BASE + 0x00020000)
#define FLASH_R_BASE          (AHB1PERIPH_BASE + 0x3C00)

#define FLASH_ACR     (FLASH_R_BASE + 0x00)
#define FLASH_KEYR    (FLASH_R_BASE + 0x04)
#define FLASH_OPTKEYR (FLASH_R_BASE + 0x08)
#define FLASH_SR      (FLASH_R_BASE + 0x0C)
#define FLASH_CR      (FLASH_R_BASE + 0x10)
#define FLASH_OPTCR   (FLASH_R_BASE + 0x14)
#define FLASH_OPTCR1  (FLASH_R_BASE + 0x18)

/*******************  Bits definition for FLASH_SR register  ******************/
#define FLASH_SR_EOP                         ((uint32_t)0x00000001)
#define FLASH_SR_SOP                         ((uint32_t)0x00000002)
#define FLASH_SR_WRPERR                      ((uint32_t)0x00000010)
#define FLASH_SR_PGAERR                      ((uint32_t)0x00000020)
#define FLASH_SR_PGPERR                      ((uint32_t)0x00000040)
#define FLASH_SR_PGSERR                      ((uint32_t)0x00000080)
#define FLASH_SR_BSY                         ((uint32_t)0x00010000)

/*******************  Bits definition for FLASH_CR register  ******************/
#define FLASH_CR_PG                          ((uint32_t)0x00000001)
#define FLASH_CR_SER                         ((uint32_t)0x00000002)
#define FLASH_CR_MER                         ((uint32_t)0x00000004)
#define FLASH_CR_SNB                         ((uint32_t)0x000000F8)
#define FLASH_CR_SNB_0                       ((uint32_t)0x00000008)
#define FLASH_CR_SNB_1                       ((uint32_t)0x00000010)
#define FLASH_CR_SNB_2                       ((uint32_t)0x00000020)
#define FLASH_CR_SNB_3                       ((uint32_t)0x00000040)
#define FLASH_CR_SNB_4                       ((uint32_t)0x00000080)
#define FLASH_CR_PSIZE                       ((uint32_t)0x00000300)
#define FLASH_CR_PSIZE_0                     ((uint32_t)0x00000100)
#define FLASH_CR_PSIZE_1                     ((uint32_t)0x00000200)
#define FLASH_CR_STRT                        ((uint32_t)0x00010000)
#define FLASH_CR_EOPIE                       ((uint32_t)0x01000000)
#define FLASH_CR_LOCK                        ((uint32_t)0x80000000)

#define FLASH_FLAG_BSY                 ((uint32_t)0x00010000)

#define FLASH_KEY1               ((uint32_t)0x45670123)
#define FLASH_KEY2               ((uint32_t)0xCDEF89AB)

- (void)setBits:(UInt32)address value:(UInt32)value
{
    [self.serialWireDebug writeMemory:address value:[self.serialWireDebug readMemory:address] | value];
}

- (void)clearBits:(UInt32)address value:(UInt32)value
{
    [self.serialWireDebug writeMemory:address value:[self.serialWireDebug readMemory:address] & ~value];
}

- (void)massErase
{
    if ([self.serialWireDebug readMemory:FLASH_CR] & FLASH_CR_LOCK) {
        [self.serialWireDebug writeMemory:FLASH_KEYR value:FLASH_KEY1];
        [self.serialWireDebug writeMemory:FLASH_KEYR value:FLASH_KEY2];
    }
    
    while ([self.serialWireDebug readMemory:FLASH_SR] & FLASH_FLAG_BSY);
    
    [self setBits:FLASH_CR value:FLASH_CR_MER];
    [self setBits:FLASH_CR value:FLASH_CR_STRT];
    
    while ([self.serialWireDebug readMemory:FLASH_SR] & FLASH_FLAG_BSY);
    
    [self clearBits:FLASH_CR value:FLASH_CR_MER];
    
    [self setBits:FLASH_CR value:FLASH_CR_LOCK];
}

@end
