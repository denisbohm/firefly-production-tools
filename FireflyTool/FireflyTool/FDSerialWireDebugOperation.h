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

@interface FDSerialWireDebugOperation : NSOperation

@property BOOL run;
@property FDLogger *logger;
@property FDUSBDevice *usbDevice;
@property FDSerialWireDebug *serialWireDebug;

- (void)execute;

@end
