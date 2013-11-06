//
//  FDFireflyIceRadioTest.m
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDFireflyIceRadioTest.h"

#import <ARMSerialWireDebug/FDEFM32.h>

#import <FireflyProduction/FDRadioTest.h>

@interface FDFireflyIceRadioTest () <FDRadioTestDelegate>

@property double radioTestSpeed;
@property double radioTestStrength;
@property FDRadioTest *radioTest;
@property FDRadioTestResult *radioTestResult;

@end

@implementation FDFireflyIceRadioTest

- (id)init
{
    if (self = [super init]) {
        _radioTestSpeed = 100;
        _radioTestStrength = -80;
        _radioTest = [[FDRadioTest alloc] init];
    }
    return self;
}

- (void)radioTest:(FDRadioTest *)radioTest discovered:(NSString *)name
{
    FDLog(@"discovered radio %@", name);
}

- (void)radioTest:(FDRadioTest *)radioTest complete:(NSString *)name result:(FDRadioTestResult *)result
{
    FDLog(@"completed radio test for %@: %@ %0.2f %0.3f", name, result.pass ? @"pass" : @"fail", result.rssi, result.duration);
    
    if (!result.pass) {
        FDLog(@"radio test failed");
    }
}

- (void)addNote:(NSMutableString *)notes message:(NSString *)message
{
    FDLog(message);
    if (notes.length > 0) {
        [notes appendString:@"; "];
    }
    [notes appendString:message];
}

- (BOOL)testRadio:(NSMutableString *)notes
{
    [self loadExecutable:@"FireflyRadioTest"];
    [self run:@"fd_processor_initialize"];
    [self run:@"spi_initialize"];
    [self run:@"fd_bluetooth_reset"];

    NSData *hardwareId = [self.serialWireDebug readMemory:EFM32_UNIQUE_0 length:8];
    NSMutableString *name = [NSMutableString stringWithString:@"hwid"];
    {
        uint8_t *bytes = (uint8_t *)hardwareId.bytes;
        for (NSUInteger i = 0; i < hardwareId.length; ++i) {
            uint8_t byte = bytes[i];
            [name appendFormat:@"%02x", byte];
        }
    }
    
    FDLog(@"starting radio test for %@", name);
    _radioTestResult = nil;
    [_radioTest start];
    uint8_t bytes[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *writeData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    [_radioTest startTest:name delegate:self data:writeData];
    FDExecutableFunction *radio_test = self.executable.functions[@"fd_nrf8001_test_broadcast"];
    uint32_t address = self.cortexM.heapRange.location;
    NSException *exception = nil;
    uint32_t result = 0;
    @try {
        result = [self.cortexM run:radio_test.address r0:address r1:sizeof(bytes) timeout:1000]; // ]15.0];
    } @catch (NSException *e) {
        exception = e;
    }
    [_radioTest stop];
    if (exception != nil) {
        [self addNote:notes message:@"check radio (timeout)"];
        return NO;
    }
    FDLog(@"radio test return 0x%08x result", result);
    
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
    
    NSData *verifyData = [self.serialWireDebug readMemory:address length:sizeof(bytes)];
    if (![writeData isEqualToData:verifyData]) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio data (v=%@ expected=%@)", verifyData, writeData]];
        return NO;
    }
    
    return YES;
}

- (void)run
{
    _radioTest.logger = self.logger;
    
    NSMutableString *notes = [NSMutableString string];
    
    [self testRadio:notes];
}

@end
