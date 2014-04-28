//
//  FDPoolMember.h
//  Firefly Test Pool
//
//  Created by Denis Bohm on 4/18/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <FireflyDevice/FDFireflyIce.h>

@interface FDPoolMember : NSObject

@property NSDictionary *advertisementData;
@property FDFireflyIce *fireflyIce;
@property NSString *executor;
@property NSString *version;
@property NSString *lastReset;
@property NSString *batteryVoltage;
@property NSString *chargeCurrent;
@property NSString *temperature;

@end
