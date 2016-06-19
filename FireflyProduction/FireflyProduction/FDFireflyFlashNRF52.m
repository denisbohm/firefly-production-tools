//
//  FDFireflyFlashNRF52.m
//  FireflyProduction
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF52.h"

@implementation FDFireflyFlashNRF52

- (void)setupProcessor
{
    self.pageSize = 4096;
    
    self.ramAddress = 0x20000000;
    self.ramSize = 65536;
}

#define UICR 0x10001000

#define APPROTECT 0x208

#define UICR_APPROTECT (UICR + APPROTECT)

- (BOOL)debugLock
{
    uint32_t value = [self.serialWireDebug readMemory:UICR_APPROTECT];
    return (value & 0x000000ff) != 0x000000ff;
}

- (void)setDebugLock
{
    [self.serialWireDebug writeMemory:NRF_NVMC_CONFIG value:NRF_NVMC_CONFIG_WEN_Wen];
    while (([self.serialWireDebug readMemory:NRF_NVMC_READY] & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);

    [self.serialWireDebug writeMemory:UICR_APPROTECT value:0xffffff00];
    while (([self.serialWireDebug readMemory:NRF_NVMC_READY] & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);

    [self.serialWireDebug writeMemory:NRF_NVMC_CONFIG value:NRF_NVMC_CONFIG_WEN_Ren];
    while (([self.serialWireDebug readMemory:NRF_NVMC_READY] & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);
}

@end
