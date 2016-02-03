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
    
    // ex: "ver\n\r00000008\n\r>"
    
    [_text appendString:[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]];
    
    while (true) {
        NSRange matchRange = [_text rangeOfString:@">"];
        if (matchRange.location == NSNotFound) {
            break;
        }
        matchRange.length += matchRange.location;
        matchRange.location = 0;
        NSString *match = [_text substringWithRange:matchRange];
        [_text replaceCharactersInRange:matchRange withString:@""];
        [self dispatch:match];
    }
    
    // if we are getting unrecognizable data then clear it out occasionally...
    if (_text.length > 500) {
        NSLog(@"clearing junk data");
        [_text deleteCharactersInRange:NSMakeRange(0, _text.length)];
    }
}

- (void)dispatchVer:(NSArray *)tokens
{
    NSString *value = tokens[2];
    if ([_delegate respondsToSelector:@selector(numato:ver:)]) {
        [_delegate numato:self ver:value];
    }
}

- (void)dispatchIdGet:(NSArray *)tokens
{
    NSString *value = tokens[2];
    if ([_delegate respondsToSelector:@selector(numato:id:)]) {
        [_delegate numato:self id:value];
    }
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
    uint16_t value = [tokens[2] integerValue];
    if ([_delegate respondsToSelector:@selector(numato:adc:value:)]) {
        [_delegate numato:self adc:channel value:value];
    }
}

- (void)dispatchGpioRead:(NSArray *)tokens
{
    uint8_t channel = [self parseChannel:tokens[0]];
    BOOL value = [tokens[2] isEqualToString:@"1"];
    if ([_delegate respondsToSelector:@selector(numato:gpio:value:)]) {
        [_delegate numato:self gpio:channel value:value];
    }
}

- (void)dispatchRelayRead:(NSArray *)tokens
{
    uint8_t channel = [self parseChannel:tokens[0]];
    BOOL value = [tokens[2] isEqualToString:@"on"];
    if ([_delegate respondsToSelector:@selector(numato:relay:value:)]) {
        [_delegate numato:self relay:channel value:value];
    }
}

- (void)dispatch:(NSString *)response
{
    NSArray *tokens = [response componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *command = tokens[0];
    if (tokens.count == 3) {
        if ([_delegate respondsToSelector:@selector(numato:echo:)]) {
            [_delegate numato:self echo:command];
        }
        return;
    }
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
    NSMutableData *data = [NSMutableData dataWithData:[line dataUsingEncoding:NSASCIIStringEncoding]];
    uint8_t newline = '\r';
    [data appendBytes:&newline length:1];
    [_serialPort writeData:data];
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
