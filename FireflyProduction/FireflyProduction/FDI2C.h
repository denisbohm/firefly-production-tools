//
//  FDI2C.h
//  FireflyProduction
//
//  Created by Denis Bohm on 12/28/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDLogger;
@class FDSerialEngine;

@interface FDI2C : NSObject

@property FDSerialEngine *serialEngine;
@property FDLogger *logger;

- (void)initialize;

- (void)setGpioBit:(NSUInteger)bit value:(BOOL)value;

@end
