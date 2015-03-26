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
#define FLASH_CR_PSIZE_X8
#define FLASH_CR_PSIZE_X16 FLASH_CR_PSIZE_0
#define FLASH_CR_PSIZE_X32 FLASH_CR_PSIZE_1
#define FLASH_CR_PSIZE_X64 (FLASH_CR_PSIZE_1 | FLASH_CR_PSIZE_0)
#define FLASH_CR_STRT                        ((uint32_t)0x00010000)
#define FLASH_CR_EOPIE                       ((uint32_t)0x01000000)
#define FLASH_CR_LOCK                        ((uint32_t)0x80000000)

/*******************  Bits definition for FLASH_OPTCR register  ***************/
#define FLASH_OPTCR_OPTLOCK                 ((uint32_t)0x00000001)
#define FLASH_OPTCR_OPTSTRT                 ((uint32_t)0x00000002)
#define FLASH_OPTCR_BOR_LEV_0               ((uint32_t)0x00000004)
#define FLASH_OPTCR_BOR_LEV_1               ((uint32_t)0x00000008)
#define FLASH_OPTCR_BOR_LEV                 ((uint32_t)0x0000000C)
#define FLASH_OPTCR_BFB2                    ((uint32_t)0x00000010)

#define FLASH_OPTCR_WDG_SW                  ((uint32_t)0x00000020)
#define FLASH_OPTCR_nRST_STOP               ((uint32_t)0x00000040)
#define FLASH_OPTCR_nRST_STDBY              ((uint32_t)0x00000080)
#define FLASH_OPTCR_RDP                     ((uint32_t)0x0000FF00)
#define FLASH_OPTCR_RDP_0                   ((uint32_t)0x00000100)
#define FLASH_OPTCR_RDP_1                   ((uint32_t)0x00000200)
#define FLASH_OPTCR_RDP_2                   ((uint32_t)0x00000400)
#define FLASH_OPTCR_RDP_3                   ((uint32_t)0x00000800)
#define FLASH_OPTCR_RDP_4                   ((uint32_t)0x00001000)
#define FLASH_OPTCR_RDP_5                   ((uint32_t)0x00002000)
#define FLASH_OPTCR_RDP_6                   ((uint32_t)0x00004000)
#define FLASH_OPTCR_RDP_7                   ((uint32_t)0x00008000)
#define FLASH_OPTCR_nWRP                    ((uint32_t)0x0FFF0000)
#define FLASH_OPTCR_nWRP_0                  ((uint32_t)0x00010000)
#define FLASH_OPTCR_nWRP_1                  ((uint32_t)0x00020000)
#define FLASH_OPTCR_nWRP_2                  ((uint32_t)0x00040000)
#define FLASH_OPTCR_nWRP_3                  ((uint32_t)0x00080000)
#define FLASH_OPTCR_nWRP_4                  ((uint32_t)0x00100000)
#define FLASH_OPTCR_nWRP_5                  ((uint32_t)0x00200000)
#define FLASH_OPTCR_nWRP_6                  ((uint32_t)0x00400000)
#define FLASH_OPTCR_nWRP_7                  ((uint32_t)0x00800000)
#define FLASH_OPTCR_nWRP_8                  ((uint32_t)0x01000000)
#define FLASH_OPTCR_nWRP_9                  ((uint32_t)0x02000000)
#define FLASH_OPTCR_nWRP_10                 ((uint32_t)0x04000000)
#define FLASH_OPTCR_nWRP_11                 ((uint32_t)0x08000000)

#define FLASH_OPTCR_DB1M                    ((uint32_t)0x40000000)
#define FLASH_OPTCR_SPRMOD                  ((uint32_t)0x80000000)

//

#define FLASH_FLAG_BSY                 ((uint32_t)0x00010000)

#define FLASH_KEY1               ((uint32_t)0x45670123)
#define FLASH_KEY2               ((uint32_t)0xCDEF89AB)
#define FLASH_OPT_KEY1           ((uint32_t)0x08192A3B)
#define FLASH_OPT_KEY2           ((uint32_t)0x4C5D6E7F)

#define FLASH_OPTCR_RDP_LEVEL_0 0x0000aa00
#define FLASH_OPTCR_RDP_LEVEL_1 0x00000100
#define FLASH_OPTCR_RDP_LEVEL_2 0x0000cc00

- (void)setBits:(UInt32)address value:(UInt32)value
{
    [self.serialWireDebug writeMemory:address value:[self.serialWireDebug readMemory:address] | value];
}

- (void)clearBits:(UInt32)address value:(UInt32)value
{
    [self.serialWireDebug writeMemory:address value:[self.serialWireDebug readMemory:address] & ~value];
}

- (void)replaceBits:(UInt32)address mask:(UInt32)mask value:(UInt32)value
{
    uint32_t replacement = [self.serialWireDebug readMemory:address];
    replacement = (replacement & ~mask) | value;
    [self.serialWireDebug writeMemory:address value:replacement];
}

- (void)setOptionByteReadProtection:(uint32_t)level
{
    if ([self.serialWireDebug readMemory:FLASH_OPTCR] & FLASH_OPTCR_OPTLOCK) {
        [self.serialWireDebug writeMemory:FLASH_OPTKEYR value:FLASH_OPT_KEY1];
        [self.serialWireDebug writeMemory:FLASH_OPTKEYR value:FLASH_OPT_KEY2];
    }
    
    while ([self.serialWireDebug readMemory:FLASH_SR] & FLASH_FLAG_BSY);
    
    [self replaceBits:FLASH_OPTCR mask:FLASH_OPTCR_RDP value:level];
    [self setBits:FLASH_OPTCR value:FLASH_OPTCR_OPTSTRT];
    
    while ([self.serialWireDebug readMemory:FLASH_SR] & FLASH_FLAG_BSY);
    
    [self setBits:FLASH_OPTCR value:FLASH_OPTCR_OPTLOCK];
}

- (void)writeOneTimeProgrammableBlock:(uint32_t)address data:(NSData *)data
{
    if ([self.serialWireDebug readMemory:FLASH_CR] & FLASH_CR_LOCK) {
        [self.serialWireDebug writeMemory:FLASH_KEYR value:FLASH_KEY1];
        [self.serialWireDebug writeMemory:FLASH_KEYR value:FLASH_KEY2];
    }
    
    while ([self.serialWireDebug readMemory:FLASH_SR] & FLASH_FLAG_BSY);
    
    [self replaceBits:FLASH_CR mask:FLASH_CR_PSIZE value:FLASH_CR_PSIZE_X32];
    [self setBits:FLASH_CR value:FLASH_CR_PG];
    [self.serialWireDebug writeMemory:address data:data];
    
    while ([self.serialWireDebug readMemory:FLASH_SR] & FLASH_FLAG_BSY);
    
    [self clearBits:FLASH_CR value:FLASH_CR_PG];
    
    [self setBits:FLASH_CR value:FLASH_CR_LOCK];
}


- (void)massEraseFlash
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

- (void)massEraseOptionByteReadProtection
{
    [self setOptionByteReadProtection:FLASH_OPTCR_RDP_LEVEL_0];
}

- (void)massErase
{
    uint32_t flash_optcr = [self.serialWireDebug readMemory:FLASH_OPTCR];
    if ((flash_optcr & FLASH_OPTCR_RDP) != FLASH_OPTCR_RDP_LEVEL_0) {
        [self massEraseOptionByteReadProtection];
    } else {
        [self massEraseFlash];
    }
}

- (void)setDebugLock
{
    [self setOptionByteReadProtection:FLASH_OPTCR_RDP_LEVEL_1];
}

- (BOOL)debugLock
{
    uint32_t flash_optcr = [self.serialWireDebug readMemory:FLASH_OPTCR];
    return (flash_optcr & FLASH_OPTCR_OPTLOCK) != 0;
}

@end
