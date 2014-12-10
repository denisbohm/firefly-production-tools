//
//  FDNumato.m
//  FireflyProduction
//
//  Created by Denis Bohm on 9/4/12.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDNumato.h"

@interface FDNumato () <FDSerialPortDelegate>

@property NSMutableString *text;

@end

@implementation FDNumato

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
    
    NSLog(@"numato listing to serial port %@", _serialPort.path);
}

- (void)serialPort:(FDSerialPort *)serialPort didReceiveData:(NSData *)data
{
    // command\r
    // >
    //
    // -or-
    //
    // command\r
    // result\r
    // >
    
    [_text appendString:[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]];
    
    NSString *pattern = @".*>";
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
        NSLog(@"numato response: %@", match);
        [self dispatch:match];
    }
}

- (void)dispatchVer:(NSArray *)tokens
{
    NSString *value = tokens[1];
    [_delegate numato:self ver:value];
}

- (void)dispatchIdGet:(NSArray *)tokens
{
    NSString *value = tokens[1];
    [_delegate numato:self id:value];
}

- (uint8_t)parseChannel:(NSString *)token
{
    NSRange range = [token rangeOfString:@" " options:NSBackwardsSearch];
    NSString *value = [token substringFromIndex:range.location + 1];
    return [value intValue];
}

- (void)dispatchAdcRead:(NSArray *)tokens
{
    uint8_t channel = [self parseChannel:tokens[0]];
    uint16_t value = [tokens[1] unsignedShortValue];
    [_delegate numato:self adc:channel value:value];
}

- (void)dispatchGpioRead:(NSArray *)tokens
{
    uint8_t channel = [self parseChannel:tokens[0]];
    BOOL value = [tokens[1] isEqualToString:@"on"];
    [_delegate numato:self gpio:channel value:value];
}

- (void)dispatchRelayRead:(NSArray *)tokens
{
    uint8_t channel = [self parseChannel:tokens[0]];
    BOOL value = [tokens[1] isEqualToString:@"on"];
    [_delegate numato:self relay:channel value:value];
}

- (void)dispatch:(NSString *)response
{
    NSArray *tokens = [response componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *command = tokens[0];
    if ([command isEqualToString:@"ver"]) {
        [self dispatchVer:tokens];
    } else
    if ([command isEqualToString:@"id get"]) {
        [self dispatchIdGet:tokens];
    } else
    if ([command hasPrefix:@"relay read"]) {
        [self dispatchRelayRead:tokens];
    } else
    if ([command hasPrefix:@"adc read"]) {
        [self dispatchAdcRead:tokens];
    } else
    if ([command hasPrefix:@"gpio read"]) {
        [self dispatchGpioRead:tokens];
    } else {
        NSLog(@"unexpected numato response: %@", command);
    }
}

- (void)println:(NSString *)line
{
    [_serialPort writeData:[line dataUsingEncoding:NSASCIIStringEncoding]];
    uint8_t newline[] = {'\r'};
    [_serialPort writeData:[NSData dataWithBytes:newline length:1]];
}

- (void)ver {
    [self println:@"ver"];
}

- (void)idGet
{
    [self println:@"id get"];
}

- (void)idSet:(NSString *)value
{
    if (value.length != 8) {
        @throw [NSException exceptionWithName:@"InvalidLength" reason:@"identifier must be 8 characters" userInfo:nil];
    }
    [self println:[NSString stringWithFormat:@"id set %@", value]];
}

- (void)relayOn:(uint8_t)channel
{
    [self println:[NSString stringWithFormat:@"relay on %u", channel]];
}

- (void)relayOff:(uint8_t)channel
{
    [self println:[NSString stringWithFormat:@"relay off %u", channel]];    
}

- (void)relayRead:(uint8_t)channel
{
    [self println:[NSString stringWithFormat:@"relay read %u", channel]];
}

- (void)relayReset {
    [self println:@"reset"];
}

- (void)adcRead:(uint8_t)channel
{
    [self println:[NSString stringWithFormat:@"adc read %u", channel]];
}

- (void)gpioSet:(uint8_t)channel
{
    [self println:[NSString stringWithFormat:@"gpio set %u", channel]];
}

- (void)gpioClear:(uint8_t)channel
{
    [self println:[NSString stringWithFormat:@"gpio clear %u", channel]];
}

- (void)gpioRead:(uint8_t)channel
{
    [self println:[NSString stringWithFormat:@"gpio read %u", channel]];
}

@end
