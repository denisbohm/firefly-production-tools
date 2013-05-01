//
//  FDFireflyDevice.m
//  Sync
//
//  Created by Denis Bohm on 4/3/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDBinary.h"
#import "FDDetour.h"
#import "FDFireflyDevice.h"

#if TARGET_OS_IPHONE
#import <CoreBluetooth/CoreBluetooth.h>
#else
#import <IOBluetooth/IOBluetooth.h>
#endif

@interface FDFireflyDevice () <CBPeripheralDelegate>

@property CBPeripheral *peripheral;
@property CBCharacteristic *characteristic;
@property FDDetour *detour;

@end

@implementation FDFireflyDevice

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    if (self = [super init]) {
        _peripheral = peripheral;
        _peripheral.delegate = self;
        _detour = [[FDDetour alloc] init];
    }
    return self;
}

- (void)didConnectPeripheral
{
    [_peripheral discoverServices:nil];
}

- (void)didDisconnectPeripheralError:(NSError *)error
{
    [_detour clear];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"didWriteValueForCharacteristic %@", error);
}

- (void)process:(NSData *)data
{
    FDBinary *binary = [[FDBinary alloc] initWithData:data];
    uint8_t code = [binary getUint8];
    float ax = [binary getFloat32];
    float ay = [binary getFloat32];
    float az = [binary getFloat32];
    float mx = [binary getFloat32];
    float my = [binary getFloat32];
    float mz = [binary getFloat32];
    [_delegate fireflyDevice:self ax:ax ay:ay az:az mx:mx my:my mz:mz];
    NSLog(@"code:%u ax:%f ay:%f az:%f mx:%f my:%f mz:%f", code, ax, ay, az, mx, my, mz);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"didUpdateValueForCharacteristic %@ %@", characteristic.value, error);
    [_detour detourEvent:characteristic.value];
    if (_detour.state == FDDetourStateSuccess) {
        [self process:_detour.data];
        [_detour clear];
    } else
    if (_detour.state == FDDetourStateError) {
        NSLog(@"detour error");
        [_detour clear];
    }
}

- (void)write
{
    uint8_t sequence_number = 0x00;
    uint16_t length = 1;
    uint8_t bytes[] = {sequence_number, length, length >> 8, 0x5a};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    [_peripheral writeValue:data forCharacteristic:_characteristic type:CBCharacteristicWriteWithResponse];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"didDiscoverServices %@", peripheral.name);
    for (CBService *service in peripheral.services) {
        NSLog(@"didDiscoverService %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:@"310a0002-1b95-5091-b0bd-b7a681846399"];
    NSLog(@"didDiscoverCharacteristicsForService %@", service.UUID);
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"didDiscoverServiceCharacteristic %@", characteristic.UUID);
        if ([characteristicUUID isEqualTo:characteristic.UUID]) {
            NSLog(@"found characteristic value");
            _characteristic = characteristic;
            
            [_peripheral setNotifyValue:YES forCharacteristic:_characteristic];
        }
    }
}

@end
