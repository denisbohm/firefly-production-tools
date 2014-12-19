//
//  FDPowerSupply.m
//  FireflyProduction
//
//  Created by Denis Bohm on 4/27/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDPowerSupply.h"
#import "FDSerialPort.h"

@implementation FDPowerSupplyChannel

+ (FDPowerSupplyChannel *)channel:(int)number
{
    return [[FDPowerSupplyChannel alloc] initWithNumber:number];
}

- (id)initWithNumber:(int)number
{
    if (self = [super init]) {
        _number = number;
    }
    return self;
}

- (FDPowerSupplyChannel *)clone
{
    FDPowerSupplyChannel *channel = [[FDPowerSupplyChannel alloc] init];
    channel.number = _number;
    channel.presetVoltage = _presetVoltage;
    channel.presetCurrent = _presetCurrent;
    channel.voltage = _voltage;
    channel.current = _current;
    return channel;
}

@end

@implementation FDPowerSupplyStatus

- (FDPowerSupplyStatus *)clone
{
    FDPowerSupplyStatus *status = [[FDPowerSupplyStatus alloc] init];
    status.identity = _identity;
    status.output = _output;
    status.overVoltageProtection = _overVoltageProtection;
    status.overCurrentProtection = _overCurrentProtection;
    status.constantVoltage = _constantVoltage;
    status.constantCurrent = _constantCurrent;
    status.beep = _beep;
    status.lock = _lock;
    status.memory = _memory;
    status.channels = [NSMutableArray array];
    for (FDPowerSupplyChannel *channel in _channels) {
        [status.channels addObject:[channel clone]];
    }
    return status;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString
                             stringWithFormat:@"%@, output %@, ovp %@, ocp %@, cv %@, cc %@, beep %@, lock %@, memory %u",
                             _identity,
                             _output ? @"YES" : @"NO",
                             _overVoltageProtection ? @"YES" : @"NO",
                             _overCurrentProtection ? @"YES" : @"NO",
                             _constantVoltage ? @"YES" : @"NO",
                             _constantCurrent ? @"YES" : @"NO",
                             _beep ? @"YES" : @"NO",
                             _lock ? @"YES" : @"NO",
                             _memory];
    for (FDPowerSupplyChannel *channel in _channels) {
        [text appendFormat:@", [channel %d: pv %0.2f, pc %0.3f, v %0.2f, c %0.3f]", channel.number, channel.presetVoltage, channel.presetCurrent, channel.voltage, channel.current];
    }
    return text;
}

@end

@interface FDTransaction : NSObject

@property NSString *command;
@property SEL selector;
@property int length;
@property int channel;

@end

@implementation FDTransaction

- (id)init:(NSString *)command selector:(SEL)selector length:(int)length channel:(int)channel;
{
    if (self = [super init]) {
        _command = command;
        _selector = selector;
        _length = length;
        _channel = channel;
    }
    return self;
}

@end

@interface FDPowerSupply () <FDSerialPortDelegate>
@property NSTimeInterval timeout;
@property NSMutableData *receivedData;
@property NSMutableArray *transactions;
@property FDTransaction *currentTransaction;
@property NSDate *currentTransactionTime;
@property FDPowerSupplyStatus *status;
@property NSTimer *timer;
@end

@implementation FDPowerSupply

- (id)init
{
    if (self = [super init]) {
        _timeout = 1.0;
        _receivedData = [NSMutableData data];
        _transactions = [NSMutableArray array];
        _status = [[FDPowerSupplyStatus alloc] init];
        _status.channels = [NSMutableArray arrayWithObject:[FDPowerSupplyChannel channel:1]];
    }
    return self;
}

- (BOOL)isReceivedDataComplete
{
    FDTransaction *transaction = _currentTransaction;
    if (transaction != nil) {
        if (transaction.length == 0) {
            // look for null termination
            uint8_t *bytes = (uint8_t *)_receivedData.bytes;
            uint8_t byte = bytes[_receivedData.length - 1];
            return byte == 0;
        } else {
            return _receivedData.length >= transaction.length;
        }
    }
    return NO;
}

- (void)serialPort:(FDSerialPort *)serialPort didReceiveData:(NSData *)data
{
//    NSLog(@"serial port received data: %@ '%@'", data, [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self didReceiveData:data];
    });
}

- (void)didReceiveData:(NSData *)data
{
    [_receivedData appendData:data];
    if ([self isReceivedDataComplete]) {
        NSInteger length = _receivedData.length;
        if ((_currentTransaction != nil) && (_currentTransaction.length == 0)) {
            length -= 1; // remove null termination
        }
        NSData *subdata = [_receivedData subdataWithRange:NSMakeRange(0, length)];
        [_receivedData setLength:0];
        FDTransaction *transaction = _currentTransaction;
        _currentTransaction = nil;
        [self receive:transaction data:subdata];
    }
}

- (void)receive:(FDTransaction *)transaction data:(NSData *)data
{
    SEL selector = transaction.selector;
    IMP imp = [self methodForSelector:selector];
    void (*function)(id, SEL, FDTransaction *, NSData *) = (void *)imp;
    function(self, selector, transaction, data);
}

- (void)write:(NSData *)data
{
//    NSLog(@"serial port transmit data: %@ '%@'", data, [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
    [_serialPort writeData:data];
}

- (void)write
{
    _currentTransactionTime = [NSDate date];
    NSString *command = _currentTransaction.command;
    [self write:[command dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)checkTransactionQueue
{
    if (_currentTransaction == nil) {
        if (_transactions.count > 0) {
            _currentTransaction = [_transactions firstObject];
            [_transactions removeObjectAtIndex:0];
            [self write];
            if (_currentTransaction.selector == nil) {
                _currentTransaction = nil;
            }
        }
    } else {
        NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:_currentTransactionTime];
        if (timeInterval > _timeout) {
            [self write];
        }
    }
}

- (void)send:(NSString *)command receive:(SEL)selector length:(int)length channel:(int)channel
{
    [_transactions addObject:[[FDTransaction alloc] init:command selector:selector length:length channel:channel]];
}

- (void)send:(NSString *)command receive:(SEL)selector length:(int)length
{
    [self send:command receive:selector length:length channel:0];
}

- (void)send:(NSString *)command receive:(SEL)selector
{
    [self send:command receive:selector length:0];
}

- (void)send:(NSString *)command
{
    [self send:command receive:nil];
}

- (void)checkTime:(NSTimer *)timer
{
    [self checkTransactionQueue];
}

- (void)open
{
    _serialPort.delegate = self;
    _serialPort.baudRate = 9600;
    // Bit rate of 9,600, 8 data bits, no parity, one stop bit, and hardware handshaking
    [_serialPort open];
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkTime:) userInfo:nil repeats:YES];
}

- (void)close
{
    [_timer invalidate];
    _timer = nil;
    
    [_serialPort close];
    _serialPort = nil;
    
    [_receivedData setLength:0];
    [_transactions removeAllObjects];
    _currentTransaction = nil;
}

// identity

- (void)receiveIdentity:(FDTransaction *)transaction data:(NSData *)data
{
    _status.identity = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

- (void)queryIdentity
{
    [self send:@"*IDN?" receive:@selector(receiveIdentity:data:)];
}

// status

#define PowerSupplyOverVoltageProtection 0x80
#define PowerSupplyOutput 0x40
#define PowerSupplyOverCurrentProtection 0x20
#define PowerSupplyConstantVoltage 0x10

- (void)receiveStatus:(FDTransaction *)transaction data:(NSData *)data
{
    uint8_t *bytes = (uint8_t *)data.bytes;
    uint8_t byte = bytes[0];
    _status.output = byte & PowerSupplyOutput ?  YES : NO;
    _status.overVoltageProtection = byte & PowerSupplyOverVoltageProtection ? YES : NO;
    _status.overCurrentProtection = byte & PowerSupplyOverCurrentProtection ? YES : NO;
    _status.constantVoltage = byte & PowerSupplyConstantVoltage ? YES : NO;
    _status.constantCurrent = byte & PowerSupplyConstantVoltage ? NO : YES;
    
    /*
    NSLog(@"status %02x", byte);
    NSLog(@"output %@", _status.output ? @"on" : @"off");
    NSLog(@"over voltage protection %@", _status.overVoltageProtection ? @"on" : @"off");
    NSLog(@"over current protection %@", _status.overCurrentProtection ? @"on" : @"off");
    NSLog(@"constant voltage %@", _status.constantVoltage ? @"on" : @"off");
    NSLog(@"constant current %@", _status.constantCurrent ? @"on" : @"off");
    */
    
    [_delegate powerSupply:self status:[_status clone]];
}

- (void)queryStatus
{
    [self send:@"STATUS?" receive:@selector(receiveStatus:data:) length:1];
}

- (void)setOutput:(BOOL)enabled
{
    [self send:[NSString stringWithFormat:@"OUT%d", enabled ? 1 : 0]];
}

- (void)setOverVoltageProtection:(BOOL)enabled
{
    [self send:[NSString stringWithFormat:@"OVP%d", enabled ? 1 : 0]];
}

- (void)setOverCurrentProtectionEnabled:(BOOL)enabled
{
    [self send:[NSString stringWithFormat:@"OCP%d", enabled ? 1 : 0]];
}

- (void)recall:(int)bank
{
    [self send:[NSString stringWithFormat:@"RCL%d", bank]];
}

- (void)save:(int)bank
{
    [self send:[NSString stringWithFormat:@"SAV%d", bank]];
}

// beep

- (void)beep:(BOOL)enabled
{
    [self send:[NSString stringWithFormat:@"BEEP%d", enabled ? 1 : 0]];
}

// lock

- (void)lock:(BOOL)enabled
{
    [self send:[NSString stringWithFormat:@"LOCK%d", enabled ? 1 : 0]];
}

// voltage

- (void)receivePresetVoltage:(FDTransaction *)transaction data:(NSData *)data
{
    NSString *s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    float voltage = [s floatValue];
//    NSLog(@"preset voltage is %0.2f", voltage);
    FDPowerSupplyChannel *channel = _status.channels[transaction.channel - 1];
    channel.presetVoltage = voltage;
}

- (void)queryPresetVoltage:(int)channel
{
    [self send:[NSString stringWithFormat:@"VSET%d?", channel] receive:@selector(receivePresetVoltage:data:) length:5 channel:channel];
}

- (void)setPreset:(int)channel voltage:(float)voltage
{
    [self send:[NSString stringWithFormat:@"VSET%d:%02.2f", channel, voltage]];
}

- (void)receiveVoltage:(FDTransaction *)transaction data:(NSData *)data
{
    NSString *s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    float voltage = [s floatValue];
//    NSLog(@"voltage is %0.2f", voltage);
    FDPowerSupplyChannel *channel = _status.channels[transaction.channel - 1];
    channel.voltage = voltage;
}

- (void)queryVoltage:(int)channel
{
    [self send:[NSString stringWithFormat:@"VOUT%d?", channel] receive:@selector(receiveVoltage:data:) length:5 channel:channel];
}

// current

- (void)receivePresetCurrent:(FDTransaction *)transaction data:(NSData *)data
{
    NSString *s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    float current = [s floatValue];
//    NSLog(@"preset current is %0.2f", current);
    FDPowerSupplyChannel *channel = _status.channels[transaction.channel - 1];
    channel.presetCurrent = current;
}

- (void)queryPresetCurrent:(int)channel
{
    [self send:[NSString stringWithFormat:@"ISET%d?", channel] receive:@selector(receivePresetCurrent:data:) length:6 channel:channel];
}

- (void)setPreset:(int)channel current:(float)current
{
    [self send:[NSString stringWithFormat:@"ISET%d:%01.3f", channel, current]];
}

- (void)receiveCurrent:(FDTransaction *)transaction data:(NSData *)data
{
    NSString *s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    float current = [s floatValue];
//    NSLog(@"current is %0.3f", current);
    FDPowerSupplyChannel *channel = _status.channels[transaction.channel - 1];
    channel.current = current;
}

- (void)queryCurrent:(int)channel
{
    [self send:[NSString stringWithFormat:@"IOUT%d?", channel] receive:@selector(receiveCurrent:data:) length:5 channel:channel];
}

- (void)getStatus
{
    [self queryIdentity];
    for (FDPowerSupplyChannel *channel in _status.channels) {
        [self queryPresetVoltage:channel.number];
        [self queryPresetCurrent:channel.number];
        [self queryVoltage:channel.number];
        [self queryCurrent:channel.number];
    }
    [self queryStatus];
}

@end
