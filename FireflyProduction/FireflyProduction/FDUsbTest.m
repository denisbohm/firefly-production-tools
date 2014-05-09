//
//  FDUsbTest.m
//  FireflyProduction
//
//  Created by Denis Bohm on 11/5/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDUsbTest.h"

#import <FireflyDevice/FDUSBHIDMonitor.h>

@implementation FDUsbTestResult
@end

@interface FDUsbTest () <FDUSBHIDMonitorDelegate, FDUSBHIDDeviceDelegate>

@property FDUSBHIDMonitor *monitor;
@property NSTimer *timer;
@property NSTimeInterval timeout;
@property NSData *writeData;
@property NSUInteger writeIndex;
@property NSMutableData *readData;
@property uint16_t pid;
@property FDUSBHIDDevice *device;
@property NSDate *startDate;

@end

@implementation FDUsbTest

- (id)init
{
    if (self = [super init]) {
    }
    return self;
}

- (void)start
{
}

- (void)stop
{
}

- (void)check:(NSTimer *)timer
{
    NSLog(@"check");
    NSDate *now = [NSDate date];
    if ([now timeIntervalSinceDate:_startDate] > _timeout) {
        FDUsbTestResult *result = [[FDUsbTestResult alloc] init];
        result.pass = NO;
        [_delegate usbTest:self complete:_pid result:result];
    }
}

- (void)startTest:(uint16_t)pid delegate:(id<FDUsbTestDelegate>)delegate data:(NSData *)data
{
    NSLog(@"starting test");
    _pid = pid;
    _delegate = delegate;
    _writeData = data;

    _monitor = [[FDUSBHIDMonitor alloc] init];
    _monitor.vendor = 0x2333;
    _monitor.product = _pid;
    _monitor.delegate = self;
    [_monitor start];
    
    _timer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(check:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)cancelTest:(uint16_t)pid
{
    NSLog(@"canceling test");
    [_timer invalidate];
    _timer = nil;

    [_device close];
    
    [_monitor stop];
    _monitor = nil;
}

- (void)send
{
    if (_writeIndex < _writeData.length) {
        NSLog(@"USB device send");
        uint8_t byte = ((uint8_t *)_writeData.bytes)[_writeIndex];
        uint8_t bytes[64] = {0x01, _writeIndex++, byte};
        [_device setReport:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    }
}

- (void)usbHidDevice:(FDUSBHIDDevice *)device inputReport:(NSData *)data
{
    NSLog(@"USB device data");
    [_readData appendBytes:data.bytes length:1];
    if (_readData.length >= _writeData.length) {
        [self cancelTest:_pid];
        
        FDUsbTestResult *result = [[FDUsbTestResult alloc] init];
        result.pass = YES;
        [_delegate usbTest:self complete:_pid result:result];
    }
    [self send];
}

- (void)usbHidMonitor:(FDUSBHIDMonitor *)monitor deviceAdded:(FDUSBHIDDevice *)device
{
    NSLog(@"USB device added");
    _device = device;
    _device.delegate = self;
    [_device open];
    [self send];
}

- (void)usbHidMonitor:(FDUSBHIDMonitor *)monitor deviceRemoved:(FDUSBHIDDevice *)device
{
    NSLog(@"USB device removed");
    _device.delegate = nil;
    [_device close];
    _device = nil;
}

@end
