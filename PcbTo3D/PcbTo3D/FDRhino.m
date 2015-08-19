//
//  FDRhino.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDRhino.h"

@interface FDRhino ()

@property NSMutableArray *transformStack;
@property NSAffineTransform *transform;
@property BOOL mirror;

@end

@implementation FDRhino

- (id)init
{
    if (self = [super init]) {
        _lines = [NSMutableString string];
    }
    return self;
}

+ (void)addCurve:(NSMutableString *)lines x1:(double)x1 y1:(double)y1 x2:(double)x2 y2:(double)y2 curve:(double)curve transform:(NSAffineTransform *)transform
{
    NSPoint c = [FDBoard getCenterOfCircleX1:x1 y1:y1 x2:x2 y2:y2 angle:curve];
    double radius = sqrt((x1 - c.x) * (x1 - c.x) + (y1 - c.y) * (y1 - c.y));
    double startAngle = atan2(y1 - c.y, x1 - c.x) * 180.0 / M_PI;
    double radians = (startAngle + curve / 2.0) * M_PI / 180.0;
    double xm = c.x + radius * cos(radians);
    double ym = c.y + radius * sin(radians);
    NSPoint p1 = [transform transformPoint:NSMakePoint(x1, y1)];
    NSPoint p2 = [transform transformPoint:NSMakePoint(x2, y2)];
    NSPoint pm = [transform transformPoint:NSMakePoint(xm, ym)];
    [lines appendFormat:@", (%f, %f, 0, %f, %f, 0, %f, %f, 0)", p1.x, p1.y, p2.x, p2.y, pm.x, pm.y];
}

- (void)convert:(FDBoardContainer *)container
{
    for (FDBoardCircle* circle in container.circles) {
        NSPoint p = [_transform transformPoint:NSMakePoint(circle.x, circle.y)];
        NSSize s = [_transform transformSize:NSMakeSize(circle.radius, circle.width)];
        if (circle.width == 0.0) {
            double r0 = ABS(s.width);
            [_lines appendFormat:@"PlaceCircle(%f, %f, %f, %d)\n", p.x, p.y, r0, circle.layer];
        } else {
            double r0 = ABS(s.width) - ABS(s.height) / 2.0;
            double r1 = ABS(s.width) + ABS(s.height) / 2.0;
            [_lines appendFormat:@"PlaceRing(%f, %f, %f, %f, %d)\n", p.x, p.y, r0, r1, circle.layer];
        }
    }
    
    for (FDBoardPad* pad in container.pads) {
        [_transformStack addObject:[_transform copy]];
        NSAffineTransform* xform = [NSAffineTransform transform];
        [xform translateXBy:pad.x yBy:pad.y];
        if (pad.mirror) {
            [xform scaleXBy:-1 yBy:1];
        }
        [xform rotateByDegrees:pad.rotate];
        [_transform prependTransform:xform];
        
        NSPoint p = [_transform transformPoint:NSMakePoint(0, 0)];
        double dx = pad.drill;
        double dy = pad.drill;
        if ([@"long" isEqualToString:pad.shape]) {
            dx *= 2.0;
        }
        NSSize s = [_transform transformSize:NSMakeSize(dx, dy)];
        [_lines appendFormat:@"PlacePad(%f, %f, %f, %f, %f, %d)\n", p.x, p.y, ABS(s.width), ABS(s.height), 1.0, 1];
        [_lines appendFormat:@"PlacePad(%f, %f, %f, %f, %f, %d)\n", p.x, p.y, ABS(s.width), ABS(s.height), 1.0, 16];
        
        _transform = [_transformStack lastObject];
        [_transformStack removeLastObject];
    }
    
    for (FDBoardSmd* smd in container.smds) {
        [_transformStack addObject:[_transform copy]];
        NSAffineTransform* xform = [NSAffineTransform transform];
        [xform translateXBy:smd.x yBy:smd.y];
        [xform rotateByDegrees:smd.rotate];
        if (smd.mirror) {
            [xform scaleXBy:-1 yBy:1];
        }
        [_transform prependTransform:xform];

        int layer = smd.layer;
        if (_mirror) {
            if (layer == 1) {
                layer = 16;
            } else
            if (layer == 16) {
                layer = 1;
            }
        }

        NSPoint p = [_transform transformPoint:NSMakePoint(0, 0)];
        NSSize s = [_transform transformSize:NSMakeSize(smd.dx, smd.dy)];
        [_lines appendFormat:@"PlaceSmd(%f, %f, %f, %f, %f, %d)\n", p.x, p.y, ABS(s.width), ABS(s.height), smd.roundness / 100.0, layer];

        _transform = [_transformStack lastObject];
        [_transformStack removeLastObject];
    }

    for (FDBoardPolygon* polygon in container.polygons) {
        BOOL first = YES;
        [_lines appendString:@"PlacePolygon(["];
        for (NSInteger i = 0; i < polygon.vertices.count; ++i) {
            FDBoardVertex *vertex = polygon.vertices[i];
            NSPoint p = [_transform transformPoint:NSMakePoint(vertex.x, vertex.y)];
            if (vertex.curve != 0) {
                FDBoardVertex *v2 = polygon.vertices[(i + 1) % polygon.vertices.count];
                if (first) {
                    first = NO;
                    [_lines appendFormat:@"(%f, %f, 0)", p.x, p.y];
                }
                [FDRhino addCurve:_lines x1:vertex.x y1:vertex.y x2:v2.x y2:v2.y curve:vertex.curve transform:_transform];
            } else {
                if (first) {
                    first = NO;
                    [_lines appendFormat:@"(%f, %f, 0)", p.x, p.y];
                } else {
                    [_lines appendFormat:@", (%f, %f, 0)", p.x, p.y];
                }
            }
        }
        FDBoardVertex *vertex = polygon.vertices[0];
        NSPoint p = [_transform transformPoint:NSMakePoint(vertex.x, vertex.y)];
        [_lines appendFormat:@", (%f, %f, 0)", p.x, p.y];
        [_lines appendFormat:@"], %i)\n", polygon.layer];
    }
}

- (void)convert
{
    FDBoardContainer *container = _board.container;
    _transform = [NSAffineTransform transform];
    
    [_lines appendFormat:@"boardThickness = %0.1f\n\n", _board.thickness];
    
    [self convert:container];
    
    for (FDBoardInstance* instance in container.instances) {
        FDBoardPackage *package = _board.packages[instance.package];
        if (package == nil) {
            continue;
        }
        
        [_lines appendFormat:@"PlaceInstance(\"%@\", %f, %f, %@, %f)\n", package.name, instance.x, instance.y, instance.mirror ? @"True" : @"False", instance.rotate];
        
        _transformStack = [NSMutableArray array];
        _transform = [NSAffineTransform transform];
        [_transform translateXBy:instance.x yBy:instance.y];
        if (instance.mirror) {
            [_transform scaleXBy:-1 yBy:1];
        }
        [_transform rotateByDegrees:instance.rotate];
        
        _mirror = instance.mirror;
        [self convert:package.container];
        
        [_transform invert];
        [_transform concat];
    }
    
    [_lines appendString:@"curves = []\n"];
    for (FDBoardWire* wire in container.wires) {
        if (wire.layer != 20) {
            continue;
        }
        double x1 = wire.x1;
        double y1 = wire.y1;
        double x2 = wire.x2;
        double y2 = wire.y2;
        double width = wire.width;
        double curve = wire.curve;
        if (curve == 0) {
            [_lines appendFormat:@"curves.append(rs.AddLine((%f, %f, 0), (%f, %f, 0)))\n", x1, y1, x2, y2];
        } else {
            NSPoint c = [FDBoard getCenterOfCircleX1:x1 y1:y1 x2:x2 y2:y2 angle:curve];
            double radius = sqrt((x1 - c.x) * (x1 - c.x) + (y1 - c.y) * (y1 - c.y));
            double startAngle = atan2(y1 - c.y, x1 - c.x);
            double angle = startAngle + curve * M_PI / (180 * 2.0);
            double xc = c.x + cos(angle) * radius;
            double yc = c.y + sin(angle) * radius;
            [_lines appendFormat:@"curves.append(rs.AddArc3Pt((%f, %f, 0), (%f, %f, 0), (%f, %f, 0)))\n", x1, y1, x2, y2, xc, yc];
        }
    }
    for (FDBoardVia* hole in container.holes) {
        double x = hole.x;
        double y = hole.y;
        double r = hole.drill / 2.0;
        [_lines appendFormat:@"curves.append(rs.AddCircle3Pt((%f, %f, 0), (%f, %f, 0), (%f, %f, 0)))\n", x - r, y, x + r, y, x, y + r];
    }
    [_lines appendString:@"PlacePCB(curves)\n"];
}

@end
