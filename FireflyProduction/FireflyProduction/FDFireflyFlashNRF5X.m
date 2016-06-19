//
//  FDFireflyFlashNRF5X.m
//  FireflyProduction
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF5X.h"

@implementation FDFireflyFlashNRF5X

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
