//
//  FDMultimeter.m
//  FireflyProduction
//
//  Created by Denis Bohm on 12/9/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDMultimeter.h"

@implementation FDMultimeterMeasurement
@end

@interface FDMultimeter () <FDSerialPortDelegate>

@property NSMutableData *data;

@end

@implementation FDMultimeter

@synthesize serialPort = _serialPort;

- (id)init
{
    if (self = [super init]) {
        _data = [NSMutableData data];
    }
    return self;
}

- (FDSerialPort *)serialPort
{
    return _serialPort;
}

- (void)setSerialPort:(FDSerialPort *)serialPort
{
    [_serialPort setDelegate:nil];
    
    _serialPort = serialPort;
    
    [_serialPort setDelegate:self];
    
    NSLog(@"multimeter listening to serial port %@", _serialPort.path);
}

- (void)serialPort:(FDSerialPort *)serialPort didReceiveData:(NSData *)data
{
    // <9 bytes>\r\n
    
    [_data appendData:data];
    
    while (_data.length > 0) {
        NSRange matchRange = NSMakeRange(NSNotFound, 0);
        uint8_t *bytes = (uint8_t *)_data.bytes;
        for (int i = 9; i < _data.length - 1; ++i) {
            if ((bytes[i] = '\r') && (bytes[i + 1] == '\n')) {
                matchRange.location = i - 9;
                matchRange.length = 11;
                break;
            }
        }
        if (matchRange.location == NSNotFound) {
            break;
        }
        NSData *match = [_data subdataWithRange:matchRange];
        [_data replaceBytesInRange:NSMakeRange(0, matchRange.location + matchRange.length) withBytes:NULL length:0];
        NSLog(@"multimeter response: %@", match);
        [self dispatch:match];
    }
    
    // if we are getting unrecognizable data then clear it out occasionally...
    if (_data.length > 22) {
        _data.length = 0;
    }
}

- (void)dispatch:(NSData *)data
{
    FDMultimeterMeasurement *measurement = [[FDMultimeterMeasurement alloc] init];
    
    uint8_t *bytes = (uint8_t *)data.bytes;
    uint8_t rangeCode = bytes[0];
    char digit3 = '0' + (bytes[1] & 0xf);
    char digit2 = '0' + (bytes[2] & 0xf);
    char digit1 = '0' + (bytes[3] & 0xf);
    char digit0 = '0' + (bytes[4] & 0xf);
    uint8_t functionCode = bytes[5];
    uint8_t status = bytes[6];
    uint8_t option1 = bytes[7];
    uint8_t option2 = bytes[8];
    
    measurement.judge = status & 0b1000 ? YES : NO;
    measurement.minusSign = status & 0b0100 ? YES : NO;
    measurement.lowBattery = status & 0b0010 ? YES : NO;
    measurement.overflow = status & 0b0001 ? YES : NO;

    measurement.pmax = option1 & 0b1000 ? YES : NO;
    measurement.pmin = option1 & 0b0100 ? YES : NO;
    measurement.vahz = option1 & 0b0001 ? YES : NO;

    measurement.dc = option2 & 0b1000 ? YES : NO;
    measurement.ac = option2 & 0b0100 ? YES : NO;
    measurement.autoMode = option2 & 0b0010 ? YES : NO;
    measurement.autoPowerOff = option2 & 0b0001 ? YES : NO;

    switch (functionCode) {
        case 0b0111011: // voltage
            measurement.function = FDMultimeterFunctionVoltage;
            measurement.rangeScale = 0.0001 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1.0;
            break;
        case 0b0111101: // uA current
            measurement.function = FDMultimeterFunctionMicroAmpCurrent;
            measurement.rangeScale = 0.1;
            measurement.functionScale = 1e-6;
            break;
        case 0b0111001: // mA current
            measurement.function = FDMultimeterFunctionMilliAmpCurrent;
            measurement.rangeScale = 0.01 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1e-3;
            break;
        case 0b0111111: // A current
            measurement.function = FDMultimeterFunctionAmpCurrent;
            measurement.rangeScale = 0.01 * pow(10, rangeCode & 0x7); // ??? not documented -denis
            measurement.functionScale = 1.0;
            break;
            break;
        case 0b0110011: // ohm
            measurement.function = FDMultimeterFunctionOhm;
            measurement.rangeScale = 0.1 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1.0;
            break;
        case 0b0110101: // continuity
            measurement.function = FDMultimeterFunctionContinuity;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0110001: // diode
            measurement.function = FDMultimeterFunctionDiode;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0110010: // frequency
            measurement.function = FDMultimeterFunctionFrequency;
            measurement.rangeScale = 1.0 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1.0;
            break;
        case 0b0110110: // capacitance
            measurement.function = FDMultimeterFunctionOhm;
            measurement.rangeScale = 1e-12 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1e-3;
            break;
        case 0b0110100: // temperature
            measurement.function = FDMultimeterFunctionTemperature;
            measurement.rangeScale = 1.0; // ??? not documented -denis
            measurement.functionScale = 1.0;
            break;
        case 0b0111110: // ADP0
            measurement.function = FDMultimeterFunctionADP0;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0111100: // ADP1
            measurement.function = FDMultimeterFunctionADP1;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0111000: // ADP2
            measurement.function = FDMultimeterFunctionADP2;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0111010: // ADP3
            measurement.function = FDMultimeterFunctionADP3;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        default:
            NSLog(@"multimeter unknown function");
            break;
    }

    measurement.digits = [NSString stringWithFormat:@"%c%c%c%c%c", measurement.minusSign ? '-' : '+', digit3, digit2, digit1, digit0];
    measurement.value = [measurement.digits doubleValue] * measurement.rangeScale * measurement.functionScale;
    
    if (_delegate != nil) {
        [_delegate multimeter:self measurement:measurement];
    }
}

@end
