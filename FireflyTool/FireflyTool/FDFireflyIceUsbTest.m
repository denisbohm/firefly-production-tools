//
//  FDFireflyIceUsbTest.m
//  FireflyTool
//
//  Created by Denis Bohm on 11/5/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDFireflyIceUsbTest.h"

#import <FireflyProduction/FDUsbTest.h>

#import <ARMSerialWireDebug/FDEFM32.h>

@interface FDFireflyIceUsbTest () <FDUsbTestDelegate>

@property FDUsbTest *usbTest;
@property uint16_t pid;

@end

@implementation FDFireflyIceUsbTest

- (void)addNote:(NSMutableString *)notes message:(NSString *)message
{
    FDLog(message);
    if (notes.length > 0) {
        [notes appendString:@"; "];
    }
    [notes appendString:message];
}

- (void)usbTest:(FDUsbTest *)radioTest discovered:(uint16_t)pid
{
    NSLog(@"usb discovered");
}

- (void)usbTest:(FDUsbTest *)radioTest complete:(uint16_t)pid result:(FDUsbTestResult *)result
{
    NSLog(@"usb test complete");
}

- (BOOL)testUsb:(NSMutableString *)notes
{
    _pid = 0x0003;
    
    [self loadExecutable:@"FireflyUsbTest"];
    
    FDLog(@"initializing processor");
    
    [self run:@"fd_processor_initialize"];

    [self run:@"fd_processor_wake"];
    
    FDLog(@"starting USB test for pid 0x%04x", _pid);
    uint8_t bytes[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *writeData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    /*
    _usbTest = [[FDUsbTest alloc] init];
    [_usbTest start];
    [_usbTest startTest:_pid delegate:self data:writeData];
     */
    FDExecutableFunction *usb_test = self.executable.functions[@"fd_usb_test"];
    uint32_t address = self.cortexM.heapRange.location;
    NSException *exception = nil;
    uint32_t result = 0;
    @try {
        result = [self.cortexM run:usb_test.address r0:_pid r1:address r2:sizeof(bytes) timeout:10.0];
    } @catch (NSException *e) {
        exception = e;
    }
    [_usbTest cancelTest:_pid];
    [_usbTest stop];
    if (exception != nil) {
        [self addNote:notes message:@"check USB (test timed out)"];
        return NO;
    }
    FDLog(@"USB test return 0x%08x result", result);
    
    /*
    FDRadioTestResult *radioTestResult = self.radioTestResult;
    if (!radioTestResult.pass) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio (incorrect response count v=%lu expected=%lu timeout=%@)", (unsigned long)radioTestResult.count, sizeof(bytes), radioTestResult.timeout ? @"YES" : @"NO"]];
        return NO;
    }
    if (radioTestResult.rssi < _radioTestStrength) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio strength (v=%0.1f min=%0.1f)", radioTestResult.rssi, _radioTestStrength]];
        return NO;
    }
    double speed = (sizeof(bytes) * 20) / radioTestResult.duration;
    if (speed < _radioTestSpeed) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio speed (v=%0.1f min=%0.1f)", speed, _radioTestSpeed]];
        return NO;
    }
     */
    
    NSData *verifyData = [self.serialWireDebug readMemory:address length:sizeof(bytes)];
    if (![writeData isEqualToData:verifyData]) {
        [self addNote:notes message:[NSString stringWithFormat:@"check USB data (v=%@ expected=%@)", verifyData, writeData]];
        return NO;
    }
    
    return YES;
}

- (void)run
{
    NSMutableString *notes = [NSMutableString string];
    
    [self testUsb:notes];
}

@end
