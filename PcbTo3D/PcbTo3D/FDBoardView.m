//
//  FDBoardView.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/6/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDBoardView.h"

@interface FDBoardView ()

@property BOOL mirror;

@end

@implementation FDBoardView

- (void)setLayerColors:(int)layer
{
    if (_mirror) {
        if (layer == 1) {
            layer = 16;
        } else
        if (layer == 16) {
            layer = 1;
        }
    }

    NSColor *color = [NSColor blackColor];
    switch (layer) {
        case 1: // Top
            color = [NSColor redColor];
            break;
        case 2: // Ground
            color = [NSColor cyanColor];
            break;
        case 15: // Power
            color = [NSColor magentaColor];
            break;
        case 16: // Bottom
            color = [NSColor blueColor];
            break;
    }
    [color setStroke];
    [color setFill];
}

+ (void)addCurve:(NSBezierPath *)path x1:(double)x1 y1:(double)y1 x2:(double)x2 y2:(double)y2 curve:(double)curve
{
    NSPoint c = [FDBoard getCenterOfCircleX1:x1 y1:y1 x2:x2 y2:y2 angle:curve];
    double radius = sqrt((x1 - c.x) * (x1 - c.x) + (y1 - c.y) * (y1 - c.y));
    double startAngle = atan2(y1 - c.y, x1 - c.x) * 180 / M_PI;
    double endAngle = startAngle + curve;
    [path appendBezierPathWithArcWithCenter:c radius:radius startAngle:startAngle endAngle:endAngle clockwise:NO];
}

- (void)drawContainer:(FDBoardContainer *)container
{
    for (FDBoardWire* wire in container.wires) {
        double x1 = wire.x1;
        double y1 = wire.y1;
        double x2 = wire.x2;
        double y2 = wire.y2;
        double width = wire.width;
        double curve = wire.curve;
        [self setLayerColors:wire.layer];
        NSBezierPath* path = [NSBezierPath bezierPath];
        [path setLineWidth:width];
        [path setLineCapStyle:NSRoundLineCapStyle];
        [path moveToPoint:NSMakePoint(x1, y1)];
        if (curve == 0) {
            [path lineToPoint:NSMakePoint(x2, y2)];
        } else {
            [FDBoardView addCurve:path x1:x1 y1:y1 x2:x2 y2:y2 curve:curve];
        }
        [path stroke];
    }
    
    for (FDBoardPolygon* polygon in container.polygons) {
        [self setLayerColors:polygon.layer];
        NSBezierPath* path = [NSBezierPath bezierPath];
        [path setLineWidth:polygon.width];
        [path setLineCapStyle:NSRoundLineCapStyle];
        BOOL first = YES;
        for (NSInteger i = 0; i < polygon.vertices.count; ++i) {
            FDBoardVertex *vertex = polygon.vertices[i];
            if (vertex.curve != 0) {
                double x1 = vertex.x;
                double y1 = vertex.y;
                FDBoardVertex *v2 = polygon.vertices[i + 1];
                double x2 = v2.x;
                double y2 = v2.y;
                if (first) {
                    first = NO;
                    [path moveToPoint:NSMakePoint(x1, y1)];
                }
                [FDBoardView addCurve:path x1:x1 y1:y1 x2:x2 y2:y2 curve:vertex.curve];
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
        [path fill];
        [path stroke];
    }
    
    [[NSColor blackColor] setStroke];
    for (FDBoardVia* hole in container.holes) {
        double x = hole.x;
        double y = hole.y;
        double drill = hole.drill;
        double x1 = x - drill / 2.0;
        double y1 = y - drill / 2.0;
        NSBezierPath* path = [NSBezierPath bezierPath];
        [path appendBezierPathWithOvalInRect:NSMakeRect(x1, y1, drill, drill)];
        [path setLineWidth:0.01];
        [path stroke];
    }
    
    [[NSColor greenColor] setFill];
    for (FDBoardVia* via in container.vias) {
        double x = via.x;
        double y = via.y;
        double drill = via.drill;
        double x1 = x - drill / 2.0;
        double y1 = y - drill / 2.0;
        NSBezierPath* path = [NSBezierPath bezierPath];
        [path appendBezierPathWithOvalInRect:NSMakeRect(x1, y1, drill, drill)];
        [path fill];
    }
    
    for (FDBoardCircle* circle in container.circles) {
        double x = circle.x;
        double y = circle.y;
        double radius = circle.radius;
        double width = circle.width;
        [self setLayerColors:circle.layer];
        if (width == 0.0) {
            double x1 = x - radius;
            double y1 = y - radius;
            NSBezierPath* path = [NSBezierPath bezierPath];
            [path appendBezierPathWithOvalInRect:NSMakeRect(x1, y1, radius * 2.0, radius * 2.0)];
            [path fill];
        } else {
            NSBezierPath* path = [NSBezierPath bezierPath];
            [path appendBezierPathWithArcWithCenter:NSMakePoint(x, y) radius:radius startAngle:0 endAngle:360];
            [path setLineWidth:width];
            [path stroke];
        }
    }
    
    for (FDBoardSmd* smd in container.smds) {
        [self setLayerColors:smd.layer];
        
        double dx = smd.dx;
        double dy = smd.dy;
        double x1 = -dx / 2.0;
        double y1 = -dy / 2.0;
        double radius = (smd.roundness / 100.0) * MIN(dx, dy) / 2.0;
        
        NSAffineTransform* xform = [NSAffineTransform transform];
        [xform translateXBy:smd.x yBy:smd.y];
        if (smd.mirror) {
            [xform scaleXBy:-1 yBy:1];
        }
        [xform rotateByDegrees:smd.rotate];
        [xform concat];
        
        NSBezierPath* path = [NSBezierPath bezierPath];
        [path appendBezierPathWithRoundedRect:NSMakeRect(x1, y1, dx, dy) xRadius:radius yRadius:radius];
        [path fill];
        
        [xform invert];
        [xform concat];
    }
    
    [[NSColor greenColor] setFill];
    for (FDBoardPad* pad in container.pads) {
        double radius = pad.drill / 2.0;
        double dx = pad.drill;
        double dy = pad.drill;
        if ([@"long" isEqualToString:pad.shape]) {
            dx *= 2.0;
        }
        
        NSAffineTransform* xform = [NSAffineTransform transform];
        [xform translateXBy:pad.x yBy:pad.y];
        if (pad.mirror) {
            [xform scaleXBy:-1 yBy:1];
        }
        [xform rotateByDegrees:pad.rotate];
        [xform concat];

        NSBezierPath* path = [NSBezierPath bezierPath];
        [path appendBezierPathWithRoundedRect:NSMakeRect(-dx / 2.0, -dy / 2.0, dx, dy) xRadius:radius yRadius:radius];
        [path fill];
        
        [xform invert];
        [xform concat];
    }
    
    [[NSColor grayColor] setFill];
    for (FDBoardInstance* instance in container.instances) {
        FDBoardPackage *package = _board.packages[instance.package];
        if (package == nil) {
            continue;
        }

        NSAffineTransform* xform = [NSAffineTransform transform];
        [xform translateXBy:instance.x yBy:instance.y];
        if (instance.mirror) {
            [xform scaleXBy:-1 yBy:1];
        }
        [xform rotateByDegrees:instance.rotate];
        [xform concat];
        
        _mirror = instance.mirror;
        [self drawContainer:package.container];
        
        [xform invert];
        [xform concat];
    }
    _mirror = NO;
}

- (void)drawRect:(NSRect)dirtyRect
{
    double scale = 20.0;
    
    NSAffineTransform* xform = [NSAffineTransform transform];
    [xform translateXBy:0 yBy:0];
    [xform rotateByDegrees:0];
    [xform scaleXBy:scale yBy:scale];
    [xform concat];
    
    [self drawContainer:_board.container];
    
    [xform invert];
    [xform concat];
}

@end
