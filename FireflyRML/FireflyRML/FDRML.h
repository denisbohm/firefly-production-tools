//
//  FDRML.h
//  FireflyRML
//
//  Created by Denis Bohm on 12/5/13.
//  Copyright (c) 2013 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDRMLPoint : NSObject

+ (FDRMLPoint *)pointX:(float)x y:(float)y z:(float)z;

- (id)initWithX:(float)x y:(float)y z:(float)z;

@property float x;
@property float y;
@property float z;

@end

#define RMLMakePoint(px, py, pz) [FDRMLPoint pointX:(px) y:(py) z:(pz)]

// MDX-15
// origin is at left front corner
// x-axis is to the right
// y-axis is to the back
// z-axis is up

@interface FDRML : NSObject

@property NSMutableData *data;

- (void)clear;

- (void)rmlReset;
- (void)rmlInitialize;
- (void)rmlMotorControl:(BOOL)rotatable;
- (void)rmlPlotAbsolute;
- (void)rmlPlotRelative;
- (void)rmlVelocityZ:(NSInteger)millimetersPerSecond;
- (void)rmlMove:(FDRMLPoint *)point;

- (void)rmlAbort;
- (void)rmlOutputErrorCode;
- (void)rmlOutputBufferSize;
- (void)rmlOutputRemainingBufferCapacity;

@end
