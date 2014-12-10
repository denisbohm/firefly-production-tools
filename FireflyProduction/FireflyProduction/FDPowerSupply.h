//
//  FDPowerSupply.h
//  FireflyProduction
//
//  Created by Denis Bohm on 4/27/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDPowerSupply;
@class FDSerialPort;

@interface FDPowerSupplyChannel : NSObject

@property float presetVoltage;
@property float presetCurrent;
@property float voltage;
@property float current;

@end

@interface FDPowerSupplyStatus : NSObject

@property NSString *identity;
@property BOOL output;
@property BOOL overVoltageProtection;
@property BOOL overCurrentProtection;
@property BOOL constantVoltage;
@property BOOL constantCurrent;
@property BOOL beep;
@property BOOL lock;
@property unsigned memory;
@property NSMutableArray *channels;

@end

@protocol FDPowerSupplyDelegate <NSObject>

- (void)powerSupply:(FDPowerSupply *)powerSupply status:(FDPowerSupplyStatus *)status;

@end

@interface FDPowerSupply : NSObject

@property FDSerialPort *serialPort;
@property id<FDPowerSupplyDelegate> delegate;

- (void)open;
- (void)close;

- (void)getStatus;

- (void)setOutput:(BOOL)enabled;
- (void)setOverVoltageProtection:(BOOL)enabled;
- (void)setOverCurrentProtectionEnabled:(BOOL)enabled;
- (void)recall:(int)bank;
- (void)save:(int)bank;
- (void)beep:(BOOL)enabled;
- (void)lock:(BOOL)enabled;

- (void)setPreset:(int)channel voltage:(float)voltage;
- (void)setPreset:(int)channel current:(float)current;

@end
