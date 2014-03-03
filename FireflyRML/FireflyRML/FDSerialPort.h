//
//  FDSerialPort.h
//  FireflyRML
//
//  Created by Denis Bohm on 12/5/13.
//  Copyright (c) 2013 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@interface FDSerialPort : NSObject

+ (NSArray *)findSerialPorts;
+ (NSArray *)findSerialPorts:(NSSet *)matchers;

@property id<FDSerialPortDelegate> delegate;
@property NSString *path;
@property NSUInteger baudRate;

- (void)open;
- (void)close;

- (void)writeData:(NSData *)data;

- (void)purge;

@end