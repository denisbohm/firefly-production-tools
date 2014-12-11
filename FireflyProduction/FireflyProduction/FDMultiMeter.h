//
//  FDMultiMeter.h
//  FireflyProduction
//
//  Created by Denis Bohm on 12/9/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

// Supports BK Precision Model 390A DMM

#import <Foundation/Foundation.h>

#import "FDSerialPort.h"

@class FDMultiMeter;

typedef enum {
    FDMultiMeterFunctionVoltage,
    FDMultiMeterFunctionMicroAmpCurrent,
    FDMultiMeterFunctionMilliAmpCurrent,
    FDMultiMeterFunctionAmpCurrent,
    FDMultiMeterFunctionOhm,
    FDMultiMeterFunctionContinuity,
    FDMultiMeterFunctionDiode,
    FDMultiMeterFunctionFrequency,
    FDMultiMeterFunctionCapacitance,
    FDMultiMeterFunctionTemperature,
    FDMultiMeterFunctionADP0,
    FDMultiMeterFunctionADP1,
    FDMultiMeterFunctionADP2,
    FDMultiMeterFunctionADP3,
} FDMultiMeterFunction;

@interface FDMultiMeterMeasurement : NSObject

@property BOOL judge;
@property BOOL minusSign;
@property BOOL lowBattery;
@property BOOL overflow;
@property BOOL pmax;
@property BOOL pmin;
@property BOOL vahz;
@property BOOL dc;
@property BOOL ac;
@property BOOL autoMode;
@property BOOL autoPowerOff;
@property double rangeScale;
@property double functionScale;
@property FDMultiMeterFunction function;
@property NSString *digits;
@property double value; // scaled by range and function

@end

@protocol FDMultiMeterDelegate <NSObject>

- (void)multiMeter:(FDMultiMeter *)multiMeter measurement:(FDMultiMeterMeasurement *)measurement;

@end

@interface FDMultiMeter : NSObject

@property FDSerialPort *serialPort;
@property id<FDMultiMeterDelegate> delegate;

@end
