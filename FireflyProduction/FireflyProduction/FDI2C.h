//
//  FDI2C.h
//  FireflyProduction
//
//  Created by Denis Bohm on 12/28/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDLogger;
@class FDSerialEngine;

// ADBUS 0-7 (GPIO low byte)
#define FDI2C_GPIO_WIRE_ORANGE 0 // SCL (TCK)
#define FDI2C_GPIO_WIRE_YELLOW 1 // SDA (TDI)
#define FDI2C_GPIO_WIRE_GREEN  2 // SDA (TDO)
#define FDI2C_GPIO_WIRE_BROWN  3 // TMS
#define FDI2C_GPIO_WIRE_GRAY   4 // GPIOL0
#define FDI2C_GPIO_WIRE_PURPLE 5 // GPIOL1
#define FDI2C_GPIO_WIRE_WHITE  6 // GPIOL2
#define FDI2C_GPIO_WIRE_BLUE   7 // GPIOL3

@interface FDI2C : NSObject

@property FDSerialEngine *serialEngine;
@property FDLogger *logger;

- (void)initialize;

- (void)setRedLED:(BOOL)value;

- (void)setTristate:(NSUInteger)bit value:(BOOL)value;
- (BOOL)getTristate:(NSUInteger)bit;

@property NSUInteger sdaBit;
@property NSUInteger sclBit;

@property uint8_t address;

- (BOOL)clearBus;
- (BOOL)transmit:(uint8_t *)bytes length:(NSUInteger)length;
- (BOOL)receive:(uint8_t *)bytes length:(NSUInteger)length;

@end
