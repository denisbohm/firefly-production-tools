//
//  FDFireflyFlashNRF51.m
//  FireflyProduction
//
//  Created by Denis Bohm on 11/17/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF51.h"

@implementation FDFireflyFlashNRF51

- (void)setupProcessor
{
    self.pageSize = 1024;
    
    self.ramAddress = 0x20000000;
    self.ramSize = 32768;
}

@end
