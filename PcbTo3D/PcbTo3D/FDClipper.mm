//
//  FDClipper.m
//  PcbTo3D
//
//  Created by Denis Bohm on 11/21/15.
//  Copyright © 2015 Firefly Design. All rights reserved.
//

#import "FDClipper.h"

#include "clipper.hpp"

using namespace ClipperLib;

@interface FDClipper ()

@property CGFloat scale;

@end

@implementation FDClipper

- (id)init
{
    if (self = [super init]) {
        _scale = 1000.0;
    }
    return self;
}

- (IntPoint)clipperPoint:(NSPoint)point {
    return IntPoint(point.x * _scale, point.y * _scale);
}

- (NSPoint)point:(IntPoint)clipperPoint
{
    return NSMakePoint(clipperPoint.X / _scale, clipperPoint.Y / _scale);
}

- (Path)clipperPath:(NSBezierPath *)bezierPath
{
    Path clipperPath;
    double flatness = [NSBezierPath defaultFlatness];
    [NSBezierPath setDefaultFlatness:0.01];
    NSBezierPath *flatPath = [bezierPath bezierPathByFlatteningPath];
    [NSBezierPath setDefaultFlatness:flatness];
    for (int i = 0; i < flatPath.elementCount; ++i) {
        NSPoint	points[3];
        NSBezierPathElement kind = [flatPath elementAtIndex:i associatedPoints:points];
        switch (kind) {
            case NSMoveToBezierPathElement:
            case NSLineToBezierPathElement: {
                NSPoint p = points[0];
                clipperPath << [self clipperPoint:p];
            } break;
            default:
                break;
        }
    }
    return clipperPath;
}

- (NSBezierPath *)bezierPath:(Path)clipperPath
{
    NSBezierPath *bezierPath = [NSBezierPath bezierPath];
    NSPoint p0;
    for (auto it = std::begin(clipperPath); it != std::end(clipperPath); ++it) {
        NSPoint point = [self point:*it];
        if (bezierPath.elementCount == 0) {
            p0 = point;
            [bezierPath moveToPoint:point];
        } else {
            [bezierPath lineToPoint:point];
        }
    }
    [bezierPath lineToPoint:p0];
    return bezierPath;
}

- (NSBezierPath *)path:(NSBezierPath *)path offset:(CGFloat)offset
{
    Path subj = [self clipperPath:path];
    Paths solution;
    ClipperOffset co;
    co.AddPath(subj, jtMiter, etClosedPolygon);
    co.Execute(solution, offset * _scale);
    NSBezierPath *offsetPath = [NSBezierPath bezierPath];
    for (auto it = std::begin(solution); it != std::end(solution); ++it) {
        [offsetPath appendBezierPath:[self bezierPath:*it]];
    }
    return offsetPath;
}

@end
