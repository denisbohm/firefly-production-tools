//
//  FDUSBPort.h
//  FireflyUpdate
//
//  Created by Denis Bohm on 10/8/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#import <FireflyDevice/FDBinary.h>
#import <FireflyDevice/FDFireflyIce.h>
#import <FireflyDevice/FDFireflyIceChannelUSB.h>
#import <FireflyDevice/FDFireflyIceCoder.h>
#import <FireflyDevice/FDFireflyIceSimpleTask.h>
#import <FireflyDevice/FDFirmwareUpdateTask.h>
#import <FireflyDevice/FDHardwareId.h>
#import <FireflyDevice/FDHelloTask.h>
#import <FireflyDevice/FDIntelHex.h>
#import <FireflyDevice/FDUSBHIDMonitor.h>

@interface FDUSBPort : NSObject

@property NSString *identifier;
@property NSObject *location;
@property FDUSBHIDDevice *usbHidDevice;
@property uint8_t area;
@property FDIntelHex *firmware;
@property FDFireflyIce *fireflyIce;
@property NSTextField *hardwareId;
@property NSTextField *status;
@property NSProgressIndicator *progressIndicator;

- (void)start:(FDUSBHIDDevice *)usbHidDevice;
- (void)stop;

@end
