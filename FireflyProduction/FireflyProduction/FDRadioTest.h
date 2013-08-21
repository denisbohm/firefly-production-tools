//
//  FDRadioTest.h
//  FireflyProduction
//
//  Created by Denis Bohm on 8/16/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDRadioTest;

@interface FDRadioTestResult : NSObject

@property BOOL pass;
@property BOOL timeout;
@property NSUInteger count;
@property double rssi;
@property NSTimeInterval duration;

@end

@protocol FDRadioTestDelegate <NSObject>

- (void)radioTest:(FDRadioTest *)radioTest discovered:(NSString *)name;
- (void)radioTest:(FDRadioTest *)radioTest complete:(NSString *)name result:(FDRadioTestResult *)result;

@end

@class FDLogger;

@interface FDRadioTest : NSObject

@property FDLogger *logger;

- (void)start;

- (void)startTest:(NSString *)name delegate:(id<FDRadioTestDelegate>)delegate data:(NSData *)data;
- (void)cancelTest:(NSString *)name;

@end
