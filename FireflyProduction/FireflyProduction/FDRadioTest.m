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
@property CBPeripheral *peripheral;
@property CBCharacteristic *characteristic;
@property NSUInteger rssiCount;
@property NSData *writeData;
@property NSDate *writeStart;
@property NSDate *writeEnd;
@property NSUInteger writeIndex;
@property NSUInteger writeCount;

@end

@implementation FDRadioTestContext
@end

@interface FDRadioTest () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property CBCentralManager *centralManager;
@property CBUUID *dataCharacteristicUUID;
@property NSMutableDictionary *tests;
@property NSTimer *timer;
@property NSTimeInterval timeout;
@end

@implementation FDRadioTest

- (id)init
{
    if (self = [super init]) {
        _tests = [NSMutableDictionary dictionary];
        _dataCharacteristicUUID = [CBUUID UUIDWithString:@"2a24"]; // Device Information: Model Number String
        _timeout = 55.0;
    }
    return self;
}

- (void)start
{
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(check:) userInfo:nil repeats:YES];
}

- (void)check:(NSTimer *)timer
{
    NSDate *now = [NSDate date];
    for (FDRadioTestContext *context in [_tests allValues]) {
        if ((context.start != nil) && ([now timeIntervalSinceDate:context.start] > _timeout)) {
            [_tests removeObjectForKey:context.name];
            [context.delegate radioTest:self complete:context.name result:nil];
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
    [_tests removeObjectForKey:name];
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
        [_tests removeObjectForKey:peripheral.name];
        FDRadioTestResult *result = [[FDRadioTestResult alloc] init];
        result.pass = context.writeCount == context.writeData.length;
        result.rssi = [context.RSSI doubleValue];
        result.duration = [context.writeEnd timeIntervalSinceDate:context.writeStart];
        [context.delegate radioTest:self complete:peripheral.name result:result];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    FDLog(@"didDiscoverServices %@ : %@", peripheral.name, error);
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)setCharacteristicValue:(FDRadioTestContext *)context
{
    FDLog(@"setCharacteristicValue");
    [context.peripheral readRSSI];
    
    ++context.writeCount;
    uint8_t byte = ((uint8_t *)context.writeData.bytes)[context.writeIndex];
    uint8_t bytes[20] = {0x01, context.writeIndex++, byte};
    [context.peripheral writeValue:[NSData dataWithBytes:bytes length:sizeof(bytes)] forCharacteristic:context.characteristic type:CBCharacteristicPropertyWrite];
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
                [self setCharacteristicValue:context];
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
        if (context.writeCount == context.writeData.length) {
            context.writeEnd = [NSDate date];
            [_centralManager cancelPeripheralConnection:peripheral];
        } else {
            [self setCharacteristicValue:context];
        }
    }
}

@end
