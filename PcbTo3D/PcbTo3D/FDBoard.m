//
//  FDBoard.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDBoard.h"

@interface FDBoardUtilities : NSObject

+ (void)addCurve:(NSBezierPath *)path x1:(double)x1 y1:(double)y1 x2:(double)x2 y2:(double)y2 curve:(double)curve;

@end

@implementation FDBoardUtilities

+ (void)addCurve:(NSBezierPath *)path x1:(double)x1 y1:(double)y1 x2:(double)x2 y2:(double)y2 curve:(double)curve
{
    NSPoint c = [FDBoard getCenterOfCircleX1:x1 y1:y1 x2:x2 y2:y2 angle:curve];
    double radius = sqrt((x1 - c.x) * (x1 - c.x) + (y1 - c.y) * (y1 - c.y));
    double startAngle = atan2(y1 - c.y, x1 - c.x) * 180 / M_PI;
    double endAngle = startAngle + curve;
    [path appendBezierPathWithArcWithCenter:c radius:radius startAngle:startAngle endAngle:endAngle clockwise:curve < 0];
}

@end

@implementation FDBoardWire

- (NSBezierPath *)bezierPath
{
    NSBezierPath* path = [NSBezierPath bezierPath];
    [path setLineWidth:_width];
    [path setLineCapStyle:NSRoundLineCapStyle];
    [path moveToPoint:NSMakePoint(_x1, _y1)];
    if (_curve == 0) {
        [path lineToPoint:NSMakePoint(_x2, _y2)];
    } else {
        [FDBoardUtilities addCurve:path x1:_x1 y1:_y1 x2:_x2 y2:_y2 curve:_curve];
    }
    return path;
}

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

- (NSBezierPath *)bezierPath
{
    NSBezierPath* path = [NSBezierPath bezierPath];
    [path setLineWidth:_width];
    [path setLineCapStyle:NSRoundLineCapStyle];
    BOOL first = YES;
    for (NSInteger i = 0; i < _vertices.count; ++i) {
        FDBoardVertex *vertex = _vertices[i];
        if (vertex.curve != 0) {
            double x1 = vertex.x;
            double y1 = vertex.y;
            FDBoardVertex *v2 = _vertices[(i + 1) % _vertices.count];
            double x2 = v2.x;
            double y2 = v2.y;
            if (first) {
                first = NO;
                [path moveToPoint:NSMakePoint(x1, y1)];
            }
            [FDBoardUtilities addCurve:path x1:x1 y1:y1 x2:x2 y2:y2 curve:vertex.curve];
        } else {
            if (first) {
                first = NO;
                [path moveToPoint:NSMakePoint(vertex.x, vertex.y)];
            } else {
                [path lineToPoint:NSMakePoint(vertex.x, vertex.y)];
            }
        }
    }
    [path closePath];
    return path;
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

@implementation FDBoardContactRef
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
        _contactRefs = [NSMutableArray array];
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
        _thickness = 1.6;
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
    if (ar < 0) {
        ar += 2.0 * M_PI;
    }
    
    double a1 = atan2(y1 - yc1, x1 - xc1);
    double a2 = atan2(y2 - yc1, x2 - xc1);
    double a12 = ccwdiff(a1, a2);
    double ad = a12 - ar;
    
    double b1 = atan2(y1 - yc2, x1 - xc2);
    double b2 = atan2(y2 - yc2, x2 - xc2);
    double b12 = ccwdiff(b1, b2);
    double bd = b12 - ar;
    
    if (fabs(ad) < fabs(bd)) {
        return NSMakePoint(xc1, yc1);
    } else {
        return NSMakePoint(xc2, yc2);
    }
}

@end
