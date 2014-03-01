//
//  FDBoard.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDBoard.h"

@implementation FDBoardWire
@end

@implementation FDBoardVertex
@end

@implementation FDBoardPolygon

- (id)init
{
    self = [super init];
    if (self) {
        _vertices = [NSMutableArray array];
    }
    return self;
}

@end

@implementation FDBoardVia
@end

@implementation FDBoardCircle
@end

@implementation FDBoardHole
@end

@implementation FDBoardSmd
@end

@implementation FDBoardPad
@end

@implementation FDBoardInstance
@end

@implementation FDBoardContainer

- (id)init
{
    self = [super init];
    if (self) {
        _wires = [NSMutableArray array];
        _polygons = [NSMutableArray array];
        _vias = [NSMutableArray array];
        _circles = [NSMutableArray array];
        _holes = [NSMutableArray array];
        _smds = [NSMutableArray array];
        _pads = [NSMutableArray array];
        _instances = [NSMutableArray array];
    }
    return self;
}

@end

@implementation FDBoardPackage

- (id)init
{
    self = [super init];
    if (self) {
        _container = [[FDBoardContainer alloc] init];
    }
    return self;
}

@end

@implementation FDBoard

- (id)init
{
    self = [super init];
    if (self) {
        _packages = [NSMutableDictionary dictionary];
        _container = [[FDBoardContainer alloc] init];
    }
    return self;
}

static double ccwdiff(double a1, double a2) {
    if (a2 < a1) {
        a2 += 2.0 * M_PI;
    }
    return a2 - a1;
}

+ (NSPoint)getCenterOfCircleX1:(double)x1 y1:(double)y1 x2:(double)x2 y2:(double)y2 angle:(double)angle
{
    double xm = (x1 + x2) / 2.0;
    double ym = (y1 + y2) / 2.0;
    double a = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)) / 2.0;
    double theta = (angle * M_PI / 180.0) / 2.0;
    double b = a / tan(theta);
    if (y1 == y2) {
        return NSMakePoint(xm, ym + b);
    }
    if (x1 == x2) {
        return NSMakePoint(xm + b, ym);
    }
    double im = (x2 - x1) / (y2 - y1);
    double xc1 = -b / sqrt(im * im + 1) + xm;
    double yc1 = im * (xm - xc1) + ym;
    double xc2 = b / sqrt(im * im + 1) + xm;
    double yc2 = im * (xm - xc2) + ym;
    
    double ar = angle * M_PI / 180.0;
    
    double a1 = atan2(y1 - yc1, x1 - xc1);
    double a2 = atan2(y2 - yc1, x2 - xc1);
    double a12 = ccwdiff(a1, a2);
    double ad = a12 - ar;
    
    double b1 = atan2(y1 - yc2, x1 - xc2);
    double b2 = atan2(y2 - yc2, x2 - xc2);
    double b12 = ccwdiff(b1, b2);
    double bd = b12 - ar;
    
    if (abs(ad) < abs(bd)) {
        return NSMakePoint(xc1, yc1);
    } else {
        return NSMakePoint(xc2, yc2);
    }
}

@end
