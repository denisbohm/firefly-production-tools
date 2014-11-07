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
@property NSUInteger writeIndex;
@property NSMutableData *readData;
@property FDUSBHIDDevice *device;
@property NSDate *startDate;
@property BOOL done;

@end

@implementation FDUsbTest

- (id)init
{
    if (self = [super init]) {
    }
    return self;
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

- (void)start
{
    NSLog(@"USB test starting");
    _monitor = [[FDUSBHIDMonitor alloc] init];
    _monitor.vendor = _vid;
    _monitor.product = _pid;
    _monitor.delegate = self;
    [_monitor start];
    
    _timer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(check:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stop
{
    NSLog(@"USB test stopping");
    [_timer invalidate];
    _timer = nil;
    
    [_device close];
    
    [_monitor stop];
    _monitor = nil;
}

- (void)complete
{
    NSLog(@"USB test complete");
    [self stop];
}

- (void)send
{
    if (_writeIndex < _writeData.length) {
        NSLog(@"USB device send data");
        uint8_t byte = ((uint8_t *)_writeData.bytes)[_writeIndex];
        uint8_t bytes[64] = {0x01, _writeIndex++, byte};
        [_device setReport:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    } else
    if (!_done) {
        NSLog(@"USB device send done");
        _done = YES;
        uint8_t bytes[64] = {0x02};
        [_device setReport:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    }
}

- (void)usbHidDevice:(FDUSBHIDDevice *)device inputReport:(NSData *)data
{
    NSLog(@"USB device data");
    [_readData appendBytes:data.bytes length:1];
    if (_readData.length >= _writeData.length) {
        [self complete];
        
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
