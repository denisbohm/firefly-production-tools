//
//  FDSerialWireDebugOperation.m
//  FireflyTool
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDFireflyIceMint.h"
#import "FDFireflyIceRadioTest.h"
#import "FDFireflyIceTest.h"
#import "FDSerialWireDebugOperation.h"

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialEngine.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>
#import <ARMSerialWireDebug/FDUSBDevice.h>

@implementation FDSerialWireDebugOperation

- (id)init
{
    if (self = [super init]) {
        _run = YES;
        _logger = [[FDLogger alloc] init];
    }
    return self;
}

- (void)initialize
{
    [_usbDevice open];

    FDSerialEngine *serialEngine = [[FDSerialEngine alloc] init];
    serialEngine.timeout = 0; // !!! need to move swd to a separate thread and enable timeout -denis
    serialEngine.usbDevice = _usbDevice;
    _serialWireDebug = [[FDSerialWireDebug alloc] init];
    _serialWireDebug.serialEngine = serialEngine;
    [_serialWireDebug initialize];
    [_serialWireDebug setGpioIndicator:true];
}

- (void)hardReset
{
    [_serialWireDebug setGpioReset:true];
    [_serialWireDebug.serialEngine write];
    [NSThread sleepForTimeInterval:0.001];
    [_serialWireDebug setGpioReset:false];
    [_serialWireDebug.serialEngine write];
    [NSThread sleepForTimeInterval:0.100];
}

- (void)attach
{
    [self hardReset];
    
    FDCortexM *cortexM = [[FDCortexM alloc] init];
    cortexM.logger = _logger;
    cortexM.serialWireDebug = _serialWireDebug;
    [cortexM identify];

    [_serialWireDebug halt];
    FDLog(@"CPU Halted %@", [_serialWireDebug isHalted] ? @"YES" : @"NO");
}

- (void)execute
{
    NSArray *tasks = @[
//                       [[FDFireflyIceTest alloc] init],
//                       [[FDFireflyIceRadioTest alloc] init],
                       [[FDFireflyIceMint alloc] init],
                       ];
    for (FDSerialWireDebugTask *task in tasks) {
        task.logger = _logger;
        task.serialWireDebug = _serialWireDebug;
        [task run];
    }
}

- (void)main
{
    @try {
        [self initialize];
        while (!self.isCancelled) {
            [NSThread sleepForTimeInterval:0.25];
            if ([_serialWireDebug getGpioDetect] && [self run]) {
                self.run = NO;
                [NSThread sleepForTimeInterval:0.25];
                [self attach];
                [self execute];
            }
        }
    } @catch (NSException *e) {
        FDLog(@"unexpected exception: %@\n%@", e, [e callStackSymbols]);
    }
    [_usbDevice close];
}

@end
