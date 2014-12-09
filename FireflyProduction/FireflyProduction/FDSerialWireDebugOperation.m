//
//  FDSerialWireDebugOperation.m
//  FireflyTool
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <FireflyProduction/FDSerialWireDebugOperation.h>
#import <FireflyProduction/FDSerialWireDebugTask.h>

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialEngine.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>
#import <ARMSerialWireDebug/FDUSBDevice.h>

@interface FDSerialWireDebugOperation ()

@property BOOL detected;

@end

@implementation FDSerialWireDebugOperation

- (id)init
{
    if (self = [super init]) {
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
    _serialWireDebug.maskInterrupts = YES;
    _serialWireDebug.serialEngine = serialEngine;
    [_serialWireDebug initialize];
    [_serialWireDebug setGpioIndicator:YES];
}

- (void)hardReset
{
    [_serialWireDebug setGpioReset:YES];
    [_serialWireDebug.serialEngine write];
    [NSThread sleepForTimeInterval:0.001];
    [_serialWireDebug setGpioReset:NO];
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
    
    /*
    FDLog(@"starting mass erase...");
    [_serialWireDebug massErase];
    [_serialWireDebug reset];
    [_serialWireDebug halt];
    [_serialWireDebug step];
    [_serialWireDebug halt];
    FDLog(@"mass erase complete");
     */
}

- (void)execute
{
    NSArray *tasks = [_delegate serialWireDebugOperationTasks];
    for (FDSerialWireDebugTask *task in tasks) {
        task.logger = _logger;
        task.serialWireDebug = _serialWireDebug;
        task.resources = _resources;
        [task run];
    }
}

- (void)main
{
    @try {
        [self initialize];
        while (!self.isCancelled) {
            [NSThread sleepForTimeInterval:0.25];
            if ([_serialWireDebug getGpioDetect]) {
                if (!_detected) {
                    _detected = YES;
                    [_delegate serialWireDebugOperationDetected:_detected];
                    if (_autoRun) {
                        self.run = YES;
                    }
                }
                
                if (self.run) {
                    [NSThread sleepForTimeInterval:0.5];
                    @try {
                        [_delegate serialWireDebugOperationStarting];
                        [self attach];
                        [self execute];
                        self.run = NO;
                        [_delegate serialWireDebugOperationComplete:YES];
                    } @catch (NSException *e) {
                        FDLog(@"unexpected exception: %@\n%@", e, [e callStackSymbols]);
                        [_delegate serialWireDebugOperationComplete:NO];
                    }
                }
            } else {
                if (_detected) {
                    self.run = NO;
                    _detected = NO;
                    [_delegate serialWireDebugOperationDetected:_detected];
                }
            }
        }
    } @catch (NSException *e) {
        if (![@"USBDeviceClosed" isEqualToString:e.name]) {
            FDLog(@"unexpected exception: %@\n%@", e, [e callStackSymbols]);
        }
    }
    [_usbDevice close];
}

@end
