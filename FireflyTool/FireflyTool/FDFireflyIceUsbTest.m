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

@property uint16_t vid;
@property uint16_t pid;

@property FDUsbTest *usbTest;

@end

@implementation FDFireflyIceUsbTest

- (id)init
{
    if (self = [super init]) {
        _vid = 0x2333;
        _pid = 0x0003;
    }
    return self;
}

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
    uint8_t bytes[] = {1};
    NSData *writeData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    
    [self loadExecutable:@"FireflyUsbTest"];
    
    FDLog(@"initializing processor");
    
    [self run:@"fd_hal_processor_initialize"];

    [self run:@"fd_hal_processor_wake"];
    
    FDLog(@"starting USB test with vid 0x%04x / pid 0x%04x", _vid, _pid);
    _usbTest = [[FDUsbTest alloc] init];
    _usbTest.delegate = self;
    _usbTest.vid = _vid;
    _usbTest.pid = _pid;
    _usbTest.writeData = writeData;
    [_usbTest start];
    FDExecutableFunction *usb_test = self.executable.functions[@"fd_usb_test"];
    usb_test.address = 0x200000d8; // !!! run init code and main from there (not sure why we need init) -denis
    uint32_t address = self.cortexM.heapRange.location;
    NSException *exception = nil;
    uint32_t result = 0;
    @try {
        result = [self.cortexM run:usb_test.address r0:_pid r1:address r2:sizeof(bytes) timeout:5.0];
    } @catch (NSException *e) {
        exception = e;
    }
    [_usbTest stop];
    if (exception != nil) {
        [self addNote:notes message:@"check USB (test timed out)"];
        return NO;
    }
    FDLog(@"USB test return 0x%08x result", result);
    
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
    
    if (![self testUsb:notes]) {
        @throw [NSException exceptionWithName:@"UsbNotDiscovered" reason:@"USB not discovered" userInfo:nil];
    }

}

@end
