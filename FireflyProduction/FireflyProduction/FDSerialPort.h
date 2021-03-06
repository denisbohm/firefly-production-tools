//
//  FDSerialPort.h
//  FireflyProduction
//
//  Created by Denis Bohm on 12/5/13.
//  Copyright (c) 2013 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <IOKit/hid/IOHIDManager.h>

@class FDSerialPort;

@protocol FDSerialPortDelegate <NSObject>

- (void)serialPort:(FDSerialPort *)serialPort didReceiveData:(NSData *)data;

@end

@protocol FDSerialPortMatcher <NSObject>

- (BOOL)matches:(io_object_t)service;

@end

@interface FDSerialPortMatcherUSB : NSObject<FDSerialPortMatcher>

+ (FDSerialPortMatcherUSB *)matcher:(uint16_t)vid pid:(uint16_t)pid;

@property uint16_t vid;
@property uint16_t pid;

@end

typedef enum {
    FDSerialPortParityNone,
    FDSerialPortParityEven,
    FDSerialPortParityOdd,
} FDSerialPortParity;

@interface FDSerialPort : NSObject

+ (NSArray *)findSerialPorts;
+ (NSArray *)findSerialPorts:(NSSet *)matchers;
+ (NSString *)getSerialPortPathWithService:(io_service_t)service;
+ (NSString *)getSerialPortPath:(IOHIDDeviceRef)deviceRef;

@property id<FDSerialPortDelegate> delegate;
@property NSString *path;
@property NSUInteger baudRate;
@property NSUInteger dataBits;
@property FDSerialPortParity parity;

- (void)open;
- (void)close;

- (void)writeData:(NSData *)data;

- (void)purge;

@end