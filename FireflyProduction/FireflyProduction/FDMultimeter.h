//
//  FDMultimeter.h
//  FireflyProduction
//
//  Created by Denis Bohm on 12/9/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

// Supports BK Precision Model 390A DMM

#import <Foundation/Foundation.h>

#import "FDSerialPort.h"

@class FDMultimeter;

typedef enum {
    FDMultimeterFunctionVoltage,
    FDMultimeterFunctionMicroAmpCurrent,
    FDMultimeterFunctionMilliAmpCurrent,
    FDMultimeterFunctionAmpCurrent,
    FDMultimeterFunctionOhm,
    FDMultimeterFunctionContinuity,
    FDMultimeterFunctionDiode,
    FDMultimeterFunctionFrequency,
    FDMultimeterFunctionCapacitance,
    FDMultimeterFunctionTemperature,
    FDMultimeterFunctionADP0,
    FDMultimeterFunctionADP1,
    FDMultimeterFunctionADP2,
    FDMultimeterFunctionADP3,
} FDMultimeterFunction;

@interface FDMultimeterMeasurement : NSObject

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
@property FDMultimeterFunction function;
@property NSString *digits;
@property double value; // scaled by range and function

@end

@protocol FDMultimeterDelegate <NSObject>

- (void)multimeter:(FDMultimeter *)multimeter measurement:(FDMultimeterMeasurement *)measurement;

@end

@interface FDMultimeter : NSObject

@property FDSerialPort *serialPort;
@property id<FDMultimeterDelegate> delegate;

@end
