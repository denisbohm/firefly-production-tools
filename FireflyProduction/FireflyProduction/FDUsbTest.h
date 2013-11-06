//
//  FDUsbTest.h
//  FireflyProduction
//
//  Created by Denis Bohm on 11/5/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDUsbTestResult : NSObject

@property BOOL pass;
@property BOOL timeout;
@property NSUInteger count;
@property NSTimeInterval duration;

@end

@class FDUsbTest;

@protocol FDUsbTestDelegate <NSObject>

- (void)usbTest:(FDUsbTest *)radioTest discovered:(uint16_t)pid;
- (void)usbTest:(FDUsbTest *)radioTest complete:(uint16_t)pid result:(FDUsbTestResult *)result;

@end

@class FDLogger;

@interface FDUsbTest : NSObject

@property FDLogger *logger;
@property id<FDUsbTestDelegate> delegate;

- (void)start;
- (void)stop;

- (void)startTest:(uint16_t)pid delegate:(id<FDUsbTestDelegate>)delegate data:(NSData *)data;
- (void)cancelTest:(uint16_t)pid;

@end
