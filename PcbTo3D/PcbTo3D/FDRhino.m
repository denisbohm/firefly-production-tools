//
//  FDRhino.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDRhino.h"

@implementation FDRhino

- (id)init
{
    if (self = [super init]) {
        _lines = [NSMutableString string];
    }
    return self;
}

- (void)convert
{
    FDBoardContainer *container = _board.container;
    
    [_lines appendString:@"boardThickness = 0.85\n\n"];
    
    for (FDBoardInstance* instance in container.instances) {
        FDBoardPackage *package = _board.packages[instance.package];
        if (package == nil) {
            continue;
        }
        
        [_lines appendFormat:@"PlaceInstance(\"%@\", %f, %f, %@, %f)\n", package.name, instance.x, instance.y, instance.mirror ? @"True" : @"False", instance.rotate];
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
