//
//  FDRML.m
//  FireflyRML
//
//  Created by Denis Bohm on 12/5/13.
//  Copyright (c) 2013 Firefly Design LLC. All rights reserved.
//

#import "FDRML.h"

@implementation FDRMLPoint

+ (FDRMLPoint *)pointX:(float)x y:(float)y z:(float)z
{
    return [[FDRMLPoint alloc] initWithX:x y:y z:z];
}

- (id)initWithX:(float)x y:(float)y z:(float)z
{
    if (self = [super init]) {
        _x = x;
        _y = y;
        _z = z;
    }
    return self;
}

@end

@interface FDRML ()

@property NSInteger coordinateScale;

@end

@implementation FDRML

- (id)init
{
    if (self = [super init]) {
        _data = [NSMutableData data];
        _coordinateScale = 40; // 0.025mm
    }
    return self;
}

- (NSString *)formatCoordinate:(float)value
{
    float parameter = value * _coordinateScale;
    /// -8388608 to 8388607
    if ((parameter < -8388608) || (parameter > 8388607)) {
        @throw [NSException exceptionWithName:@"RML_FLOAT_OUT_OF_RANGE" reason:@"RML float out of range" userInfo:nil];
    }
    return [NSString stringWithFormat:@"%0.1f", parameter];
}

- (void)clear
{
    _data.length = 0;
}

- (void)rml:(NSString *)s
{
    [_data appendData:[s dataUsingEncoding:NSASCIIStringEncoding]];
}

- (void)rmlCommand:(NSString *)command
{
    [self rml:command];
    [self rml:@";\r\n"];
}

- (void)rmlReset
{
    [self rml:@";;"];
}

- (void)rmlInitialize
{
    [self rmlCommand:@"^IN"];
}

- (void)rmlMotorControl:(BOOL)rotatable
{
    [self rmlCommand:[NSString stringWithFormat:@"!MC%u", rotatable ? 1 : 0]];
}

- (void)rmlPlotAbsolute
{
    [self rmlCommand:@"^PA"];
}

- (void)rmlPlotRelative
{
    [self rmlCommand:@"^PR"];
}

- (void)rmlVelocityZ:(NSInteger)millimetersPerSecond
{
    [self rmlCommand:[NSString stringWithFormat:@"V%ld", (long)millimetersPerSecond]];
}

- (void)rmlMove:(FDRMLPoint *)point
{
    [self rmlCommand:[NSString stringWithFormat:@"Z%@,%@,%@",
                      [self formatCoordinate:point.x],
                      [self formatCoordinate:point.y],
                      [self formatCoordinate:point.z]
                      ]];
}

- (void)rmlEscape
{
    [self rml:@"\x1b."];
}

- (void)rmlAbort
{
    [self rmlEscape];
    [self rml:@"K"];
}

- (void)rmlOutputErrorCode
{
    [self rmlEscape];
    [self rml:@"E"];
}

- (void)rmlOutputBufferSize
{
    [self rmlEscape];
    [self rml:@"L"];
}

- (void)rmlOutputRemainingBufferCapacity
{
//    [self rmlCommand:@"OE"];
    [self rmlEscape];
    [self rml:@"E"];
}

@end
