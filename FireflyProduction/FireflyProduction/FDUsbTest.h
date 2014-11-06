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
@property uint16_t vid;
@property uint16_t pid;
@property NSData *writeData;

- (void)start;
- (void)stop;

@end
