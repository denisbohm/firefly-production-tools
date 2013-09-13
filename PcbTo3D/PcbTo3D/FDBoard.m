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

static double cot(double z)
{
    return 1.0 / tan(z);
}

+ (NSPoint)getCenterOfCircleX1:(double)x1 y1:(double)y1 x2:(double)x2 y2:(double)y2 angle:(double)angle
{
    double xm = (x1 + x2) / 2.0;
    double ym = (y1 + y2) / 2.0;
    double a = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)) / 2.0;
    double theta = (angle * M_PI / 180.0) / 2.0;
    double b = a * cot(theta);
    if (y1 == y2) {
        return NSMakePoint(xm, ym + b);
    }
    if (x1 == x2) {
        return NSMakePoint(xm + b, ym);
    }
    double im = (x2 - x1) / (y2 - y1);
    double xc = -b / sqrt(im * im + 1) + xm;
    double yc = im * (xm - xc) + ym;
    return NSMakePoint(xc, yc);
}

@end
