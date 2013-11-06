//
//  FDRadioTest.m
//  FireflyProduction
//
//  Created by Denis Bohm on 8/16/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDRadioTest.h"

#import <ARMSerialWireDebug/FDLogger.h>

#if TARGET_OS_IPHONE
#import <CoreBluetooth/CoreBluetooth.h>
#else
#import <IOBluetooth/IOBluetooth.h>
#endif

@implementation FDRadioTestResult
@end

@interface FDRadioTestContext : NSObject

@property NSString *name;
@property id<FDRadioTestDelegate> delegate;
@property NSNumber *RSSI;
@property NSDate *start;
@property NSDate *send;
@property NSUInteger sendRetries;
@property CBPeripheral *peripheral;
@property CBCharacteristic *characteristic;
@property NSUInteger rssiCount;
@property NSData *writeData;
@property NSDate *writeStart;
@property NSDate *writeEnd;
@property NSUInteger writeIndex;
@property NSUInteger writeCount;
@property NSMutableArray *updates;
@property NSUInteger retries;
@property BOOL connect;

@end

@implementation FDRadioTestContext

- (id)init
{
    if (self = [super init]) {
        _updates = [NSMutableArray array];
    }
    return self;
}

- (void)reset
{
    _send = nil;
    _sendRetries = 0;
    _characteristic = nil;
    _writeStart = nil;
    _writeEnd = nil;
    _writeIndex = 0;
    _writeCount = 0;
}

@end

@interface FDRadioTest () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property CBCentralManager *centralManager;
@property CBUUID *dataCharacteristicUUID;
@property NSMutableDictionary *tests;
@property NSTimer *timer;
@property NSTimeInterval timeout;
@property NSTimeInterval sendTimeout;
@property NSUInteger sendRetries;
@property NSUInteger retries;
@end

@implementation FDRadioTest

- (id)init
{
    if (self = [super init]) {
        _tests = [NSMutableDictionary dictionary];
        _dataCharacteristicUUID = [CBUUID UUIDWithString:@"2a24"]; // Device Information: Model Number String
        _timeout = 10.0;
        _sendTimeout = 0.5;
        _sendRetries = 3;
        _retries = 3;
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (void)start
{
    _timer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(check:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stop
{
    [_timer invalidate];
    _timer = nil;
}

- (void)timeout:(FDRadioTestContext *)context
{
    [_centralManager cancelPeripheralConnection:context.peripheral];
    [_tests removeObjectForKey:context.name];
    FDRadioTestResult *result = [[FDRadioTestResult alloc] init];
    result.pass = false;
    result.timeout = true;
    result.count = context.writeCount;
    result.rssi = [context.RSSI doubleValue];
    [context.delegate radioTest:self complete:context.name result:result];
}

- (void)retry:(FDRadioTestContext *)context
{
    [context reset];
    ++context.retries;
    context.connect = YES;
}

- (void)check:(NSTimer *)timer
{
    NSDate *now = [NSDate date];
    for (FDRadioTestContext *context in [_tests allValues]) {
        if (context.start == nil) {
            continue;
        }
        if (context.connect) {
            context.connect = NO;
            [_centralManager connectPeripheral:context.peripheral options:nil];
            continue;
        }
        if ([now timeIntervalSinceDate:context.start] > _timeout) {
            [self timeout:context];
        } else
            if ((context.send != nil) && ([now timeIntervalSinceDate:context.send] > _sendTimeout)) {
                if (context.sendRetries >= _sendRetries) {
                    [self retry:context];
                } else {
                    [self setCharacteristicValue:context retry:YES];
                }
            }
    }
}

- (void)startTest:(NSString *)name delegate:(id<FDRadioTestDelegate>)delegate data:(NSData *)data
{
    FDRadioTestContext *context = [[FDRadioTestContext alloc] init];
    context.name = name;
    context.delegate = delegate;
    context.writeData = data;
    _tests[name] = context;
}

- (void)cancelTest:(NSString *)name
{
    FDRadioTestContext *context = _tests[name];
    if (context != nil) {
        [_centralManager cancelPeripheralConnection:context.peripheral];
        [_tests removeObjectForKey:name];
    }
}

- (void)centralManagerPoweredOn
{
    NSDictionary *options = @{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber  numberWithBool:YES]};
    [_centralManager scanForPeripheralsWithServices:nil options:options];
//    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"180A"]] options:nil]; // Device Information
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStateUnknown:
        case CBCentralManagerStateResetting:
        case CBCentralManagerStateUnsupported:
        case CBCentralManagerStateUnauthorized:
            break;
        case CBCentralManagerStatePoweredOff:
            break;
        case CBCentralManagerStatePoweredOn:
            [self centralManagerPoweredOn];
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSString *name = peripheral.name;
    FDRadioTestContext *context = _tests[name];
    if (context != nil) {
        if (context.peripheral == nil) {
            FDLog(@"starting radio test sequence");
            context.RSSI = RSSI;
            context.start = [NSDate date];
            context.peripheral = peripheral;
            peripheral.delegate = self;
            [_centralManager connectPeripheral:peripheral options:nil];
            [context.delegate radioTest:self discovered:name];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    FDLog(@"didConnectPeripheral %@", peripheral.name);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        [peripheral discoverServices:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    FDLog(@"didDisconnectPeripheral %@ : %@", peripheral.name, error);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        if ((context.writeEnd == nil) && (context.retries < _retries)) {
            FDLog(@"unexpected disconnect, retry opening connection");
            [self retry:context];
        } else {
            [_tests removeObjectForKey:peripheral.name];
            FDRadioTestResult *result = [[FDRadioTestResult alloc] init];
            result.pass = context.writeEnd != nil;
            result.count = context.writeCount;
            result.rssi = [context.RSSI doubleValue];
            result.duration = [context.writeEnd timeIntervalSinceDate:context.writeStart];
            result.updates = context.updates;
            [context.delegate radioTest:self complete:peripheral.name result:result];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    FDLog(@"didDiscoverServices %@ : %@", peripheral.name, error);
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)setCharacteristicValue:(FDRadioTestContext *)context retry:(BOOL)retry
{
    FDLog(@"setCharacteristicValue retry=%@", retry ? @"YES" : @"NO");
//    [context.peripheral readRSSI];
    
    context.send = [NSDate date];
    if (retry) {
        ++context.sendRetries;
    } else {
        context.sendRetries = 0;
        ++context.writeCount;
    }
    uint8_t byte = ((uint8_t *)context.writeData.bytes)[context.writeIndex];
    uint8_t bytes[20] = {0x01, context.writeIndex++, byte};
    [context.peripheral writeValue:[NSData dataWithBytes:bytes length:sizeof(bytes)] forCharacteristic:context.characteristic type:CBCharacteristicWriteWithResponse];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    FDLog(@"didDiscoverCharacteristicsForService %@ : %@", peripheral.name, error);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([characteristic.UUID isEqualTo:_dataCharacteristicUUID]) {
                context.characteristic = characteristic;
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                context.writeStart = [NSDate date];
                [self setCharacteristicValue:context retry:NO];
            }
        }
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    FDLog(@"peripheralDidUpdateRSSI %@ : %@", peripheral.name, error);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        ++context.rssiCount;
        double rssi = [peripheral.RSSI doubleValue];
        if (rssi > [context.RSSI doubleValue]) {
            context.RSSI = peripheral.RSSI;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;
{
    FDLog(@"didUpdateValueForCharacteristic %@ : %@ (error %@)", peripheral.name, characteristic.value, error);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        [context.updates addObject:characteristic.value];
        if (characteristic.value.length == 20) {
            uint8_t n = ((uint8_t *)characteristic.value.bytes)[0];
            if (n == context.writeData.length) {
                context.writeEnd = [NSDate date];
                [_centralManager cancelPeripheralConnection:peripheral];
            } else {
                if (n == context.writeCount) {
                    [self setCharacteristicValue:context retry:NO];
                }
            }
        }
    }
}

@end
