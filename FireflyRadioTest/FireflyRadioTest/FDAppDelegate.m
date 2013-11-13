//
//  FDAppDelegate.m
//  FireflyRadioTest
//
//  Created by Denis Bohm on 11/3/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"

#if TARGET_OS_IPHONE
#import <CoreBluetooth/CoreBluetooth.h>
#else
#import <IOBluetooth/IOBluetooth.h>
#endif

@interface FDRadioTestContext : NSObject

@property NSString *name;
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

@interface FDAppDelegate () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property CBCentralManager *centralManager;
@property CBUUID *dataCharacteristicUUID;
@property NSMutableDictionary *tests;
@property NSTimer *timer;
@property NSTimeInterval timeout;
@property NSTimeInterval sendTimeout;
@property NSUInteger sendRetries;
@property NSUInteger retries;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self initialize];
    [self start];
    uint8_t bytes[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    [self startTest:@"hwid1122334455667788" data:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)initialize
{
    _tests = [NSMutableDictionary dictionary];
    _dataCharacteristicUUID = [CBUUID UUIDWithString:@"310a0002-3333-5091-b0bd-b7a681846399"];
//    _dataCharacteristicUUID = [CBUUID UUIDWithString:@"2a24"]; // Device Information: Model Number String
    _timeout = 1000; // 10.0;
    _sendTimeout = 10; // 0.5;
    _sendRetries = 100; // 3;
    _retries = 100; // 3;
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
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
    NSLog(@"timeout");
    [_centralManager cancelPeripheralConnection:context.peripheral];
    [_tests removeObjectForKey:context.name];
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
            NSLog(@"again connectPeripheral");
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

- (void)startTest:(NSString *)name data:(NSData *)data
{
    FDRadioTestContext *context = [[FDRadioTestContext alloc] init];
    context.name = name;
    context.writeData = data;
    _tests[name] = context;
}

- (void)cancelTest:(NSString *)name
{
    FDRadioTestContext *context = _tests[name];
    if (context != nil) {
        NSLog(@"cancelTest");
        [_centralManager cancelPeripheralConnection:context.peripheral];
        [_tests removeObjectForKey:name];
    }
}


- (void)centralManagerPoweredOn
{
    NSLog(@"centralManagerPoweredOn");
    NSDictionary *options = nil; // @{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber  numberWithBool:YES]};
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
    NSLog(@"didDiscoverPeripheral %@", name);
    FDRadioTestContext *context = _tests[name];
    if (context != nil) {
        if (context.peripheral == nil) {
            NSLog(@"starting radio test sequence");
            context.RSSI = RSSI;
            context.start = [NSDate date];
            context.peripheral = peripheral;
            peripheral.delegate = self;
            NSLog(@"connectPeripheral");
            [_centralManager connectPeripheral:peripheral options:nil];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral %@", peripheral.name);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
//        [peripheral discoverServices:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didDisconnectPeripheral %@ : %@", peripheral.name, error);
    [_tests removeObjectForKey:peripheral.name];
    /*
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        if ((context.writeEnd == nil) && (context.retries < _retries)) {
            NSLog(@"unexpected disconnect, retry opening connection");
            [self retry:context];
        } else {
            [_tests removeObjectForKey:peripheral.name];
        }
    }
     */
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"didDiscoverServices %@ : %@", peripheral.name, error);
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)setCharacteristicValue:(FDRadioTestContext *)context retry:(BOOL)retry
{
    NSLog(@"setCharacteristicValue retry=%@", retry ? @"YES" : @"NO");
    //    [context.peripheral readRSSI];
    
    context.send = [NSDate date];
    if (retry) {
        ++context.sendRetries;
    } else {
        context.sendRetries = 0;
        ++context.writeCount;
    }
    uint8_t byte = ((uint8_t *)context.writeData.bytes)[context.writeIndex];
    uint8_t bytes[19] = {0x01, context.writeIndex++, byte};
    [context.peripheral writeValue:[NSData dataWithBytes:bytes length:sizeof(bytes)] forCharacteristic:context.characteristic type:CBCharacteristicWriteWithoutResponse];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"didDiscoverCharacteristicsForService %@ : %@", peripheral.name, error);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            NSLog(@"characteristic %@", characteristic);
            if ([characteristic.UUID isEqualTo:_dataCharacteristicUUID]) {
                NSLog(@"found characteristic");
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
    NSLog(@"peripheralDidUpdateRSSI %@ : %@", peripheral.name, error);
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
    NSLog(@"didUpdateValueForCharacteristic %@ : %@ (error %@)", peripheral.name, characteristic.value, error);
    FDRadioTestContext *context = _tests[peripheral.name];
    if (context != nil) {
        [context.updates addObject:characteristic.value];
        if (characteristic.value.length == 20) {
            uint8_t n = ((uint8_t *)characteristic.value.bytes)[0];
            if (n == context.writeData.length) {
                context.writeEnd = [NSDate date];
                NSLog(@"finished");
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
