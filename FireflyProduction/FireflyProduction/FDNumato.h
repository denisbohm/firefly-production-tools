//
//  FDNumato.h
//  FireflyProduction
//
//  Created by Denis Bohm on 9/4/12.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FDSerialPort.h"

@class FDNumato;

@protocol FDNumatoDelegate <NSObject>

@optional

- (void)numato:(FDNumato *)numato ver:(NSString *)value;
- (void)numato:(FDNumato *)numato id:(NSString *)value;
- (void)numato:(FDNumato *)numato adc:(uint8_t)channel value:(uint16_t)value;
- (void)numato:(FDNumato *)numato gpio:(uint8_t)channel value:(BOOL)value;
- (void)numato:(FDNumato *)numato relay:(uint8_t)channel value:(BOOL)value;

@end

@interface FDNumato : NSObject

@property FDSerialPort *serialPort;
@property id<FDNumatoDelegate> delegate;

- (void)ver;

- (void)idGet;
- (void)idSet:(NSString *)value;

- (void)relayOn:(uint8_t)channel;
- (void)relayOff:(uint8_t)channel;
- (void)relayRead:(uint8_t)channel;
- (void)relayReset;

- (void)adcRead:(uint8_t)channel;

- (void)gpioSet:(uint8_t)channel;
- (void)gpioClear:(uint8_t)channel;
- (void)gpioRead:(uint8_t)channel;

@end
