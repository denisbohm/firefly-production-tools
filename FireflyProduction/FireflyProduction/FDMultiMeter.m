//
//  FDMultiMeter.m
//  FireflyProduction
//
//  Created by Denis Bohm on 12/9/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDMultiMeter.h"

@interface FDMultiMeter () <FDSerialPortDelegate>

@property NSMutableString *text;

@end

@implementation FDMultiMeter

@synthesize serialPort = _serialPort;

- (id)init
{
    if (self = [super init]) {
        _text = [NSMutableString string];
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
    
    NSLog(@"multi-meter listing to serial port %@", _serialPort.path);
}

- (void)serialPort:(FDSerialPort *)serialPort didReceiveData:(NSData *)data
{
    // <9 bytes>\r\n
    
    [_text appendString:[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]];
    
    NSString *pattern = @".*\r\n";
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    while (true) {
        NSRange textRange = NSMakeRange(0, _text.length);
        NSRange matchRange = [regex rangeOfFirstMatchInString:_text options:NSMatchingReportProgress range:textRange];
        if (matchRange.location == NSNotFound) {
            break;
        }
        NSString *match = [_text substringWithRange:matchRange];
        [_text replaceCharactersInRange:matchRange withString:@""];
        NSLog(@"multi-meter response: %@", match);
        [self dispatch:match];
    }
}

- (void)dispatch:(NSString *)match
{
    if (match.length != 11) {
        NSLog(@"unexpected length");
        return;
    }
    
    FDMultiMeterMeasurement *measurement = [[FDMultiMeterMeasurement alloc] init];
    
    uint8_t rangeCode = [match characterAtIndex:0];
    char digit3 = '0' + ([match characterAtIndex:1] & 0xf);
    char digit2 = '0' + ([match characterAtIndex:2] & 0xf);
    char digit1 = '0' + ([match characterAtIndex:3] & 0xf);
    char digit0 = '0' + ([match characterAtIndex:4] & 0xf);
    uint8_t functionCode = [match characterAtIndex:5];
    uint8_t status = [match characterAtIndex:6];
    uint8_t option1 = [match characterAtIndex:7];
    uint8_t option2 = [match characterAtIndex:8];
    
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
            measurement.function = FDMultiMeterFunctionVoltage;
            measurement.rangeScale = 0.0001 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1.0;
            break;
        case 0b0111101: // uA current
            measurement.function = FDMultiMeterFunctionMicroAmpCurrent;
            measurement.rangeScale = 0.1;
            measurement.functionScale = 1e-6;
            break;
        case 0b0111001: // mA current
            measurement.function = FDMultiMeterFunctionMilliAmpCurrent;
            measurement.rangeScale = 0.01 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1e-3;
            break;
        case 0b0111111: // A current
            measurement.function = FDMultiMeterFunctionAmpCurrent;
            measurement.rangeScale = 0.01 * pow(10, rangeCode & 0x7); // ??? not documented -denis
            measurement.functionScale = 1.0;
            break;
            break;
        case 0b0110011: // ohm
            measurement.function = FDMultiMeterFunctionOhm;
            measurement.rangeScale = 0.1 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1.0;
            break;
        case 0b0110101: // continuity
            measurement.function = FDMultiMeterFunctionContinuity;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0110001: // diode
            measurement.function = FDMultiMeterFunctionDiode;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0110010: // frequency
            measurement.function = FDMultiMeterFunctionFrequency;
            measurement.rangeScale = 1.0 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1.0;
            break;
        case 0b0110110: // capacitance
            measurement.function = FDMultiMeterFunctionOhm;
            measurement.rangeScale = 1e-12 * pow(10, rangeCode & 0x7);
            measurement.functionScale = 1e-3;
            break;
        case 0b0110100: // temperature
            measurement.function = FDMultiMeterFunctionTemperature;
            measurement.rangeScale = 1.0; // ??? not documented -denis
            measurement.functionScale = 1.0;
            break;
        case 0b0111110: // ADP0
            measurement.function = FDMultiMeterFunctionADP0;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0111100: // ADP1
            measurement.function = FDMultiMeterFunctionADP1;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0111000: // ADP2
            measurement.function = FDMultiMeterFunctionADP2;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        case 0b0111010: // ADP3
            measurement.function = FDMultiMeterFunctionADP3;
            measurement.rangeScale = 1.0;
            measurement.functionScale = 1.0;
            break;
        default:
            NSLog(@"multi-meter unknown function");
            break;
    }

    measurement.digits = [NSString stringWithFormat:@"%c%c%c%c%c", measurement.minusSign ? '-' : '+', digit3, digit2, digit1, digit0];
    measurement.value = [measurement.digits doubleValue] * measurement.rangeScale * measurement.functionScale;
    
    [_delegate multiMeter:self measurement:measurement];
}

@end
