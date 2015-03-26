//
//  FDFireflyFlashSTM32F4.h
//  FireflyProduction
//
//  Created by Denis Bohm on 8/20/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDFireflyFlash.h"

@interface FDFireflyFlashSTM32F4 : FDFireflyFlash

- (void)writeOneTimeProgrammableBlock:(uint32_t)address data:(NSData *)data;

@end
