//
//  FDSerialWireDebugOperation.h
//  FireflyTool
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>
#import <ARMSerialWireDebug/FDUSBDevice.h>

@protocol FDSerialWireDebugOperationDelegate <NSObject>

- (void)serialWireDebugOperationDetected:(BOOL)detected;
- (NSArray *)serialWireDebugOperationTasks;
- (void)serialWireDebugOperationStarting;
- (void)serialWireDebugOperationComplete:(BOOL)success;

@end

@interface FDSerialWireDebugOperation : NSOperation

@property BOOL autoRun;
@property BOOL run;
@property FDLogger *logger;
@property NSDictionary *resources;
@property FDUSBDevice *usbDevice;
@property FDSerialWireDebug *serialWireDebug;
@property id<FDSerialWireDebugOperationDelegate> delegate;
@property (readonly) BOOL detected;

- (void)execute;

@end
