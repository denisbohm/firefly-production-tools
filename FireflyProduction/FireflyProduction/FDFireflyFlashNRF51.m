//
//  FDFireflyFlashNRF51.m
//  FireflyProduction
//
//  Created by Denis Bohm on 11/17/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF51.h"

@implementation FDFireflyFlashNRF51

#define NRF_NVMC 0x4001E000U
#define NRF_NVMC_READY     (NRF_NVMC + 0x400U)
#define NRF_NVMC_CONFIG    (NRF_NVMC + 0x504U)
#define NRF_NVMC_ERASEALL  (NRF_NVMC + 0x50CU)
#define NRF_NVMC_ERASEUICR (NRF_NVMC + 0x514U)

#define NRF_NVMC_READY_READY 0x00000001
#define NRF_NVMC_READY_READY_Busy  0x00000000
#define NRF_NVMC_READY_READY_Ready 0x00000001

#define NRF_NVMC_CONFIG_WEN 0x00000003
#define NRF_NVMC_CONFIG_WEN_Ren 0x00000000
#define NRF_NVMC_CONFIG_WEN_Wen 0x00000001
#define NRF_NVMC_CONFIG_WEN_Een 0x00000002

#define NRF_NVMC_ERASEALL_ERASEALL_Erase 0x00000001

#define NRF_NVMC_ERASEALL_ERASEUICR_Erase 0x00000001

- (void)setupProcessor
{
    self.pageSize = 1024;
    
    self.ramAddress = 0x20000000;
    self.ramSize = 32768;
}

- (void)setupCortexM
{
    [super setupCortexM];
    if (self.pagesPerWrite > 4) {
        self.pagesPerWrite = 4;
    }
}

- (void)massErase
{
    [self.serialWireDebug writeMemory:NRF_NVMC_CONFIG value:NRF_NVMC_CONFIG_WEN_Een];
    while (([self.serialWireDebug readMemory:NRF_NVMC_READY] & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);
    
    [self.serialWireDebug writeMemory:NRF_NVMC_ERASEALL value:NRF_NVMC_ERASEALL_ERASEALL_Erase];
    while (([self.serialWireDebug readMemory:NRF_NVMC_READY] & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);
}

- (void)eraseUICR
{
    [self.serialWireDebug writeMemory:NRF_NVMC_CONFIG value:NRF_NVMC_CONFIG_WEN_Een];
    while (([self.serialWireDebug readMemory:NRF_NVMC_READY] & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);
    
    [self.serialWireDebug writeMemory:NRF_NVMC_ERASEUICR value:NRF_NVMC_ERASEALL_ERASEUICR_Erase];
    while (([self.serialWireDebug readMemory:NRF_NVMC_READY] & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);
}

@end
