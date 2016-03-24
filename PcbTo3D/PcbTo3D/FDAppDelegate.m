//
//  FDAppDelegate.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/6/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"
#import "FDBoardView.h"
#import "FDClipper.h"
#import "FDRhino.h"

#import <DKDrawKit/DKDrawKit.h>

@interface FDTestPoint : NSObject
@property double x;
@property double y;
@property NSString *name;
@property double diameter;
@end

@implementation FDTestPoint
@end

@interface FDFixtureProperties : NSObject
@property double d;
@property double pcbThickness;
@property double maxComponentHeight;
@property double midStroke;
@property double exposed;
@property double shaft;
@property double pcbOutlineTolerance;
@property double wallThickness;
@property double ledgeThickness;
@end

@implementation FDFixtureProperties

- (id)init
{
    if (self = [super init]) {
        // Mill-Max Spring Loaded Pin 0985-0-15-20-71-14-11-0
        // 1 mm diameter mounting hole
        // 4.1 mm shaft (fits into plastic hole)
        // 0.15 exposed at max stroke
        // 1.4 mm max stroke
        // 0.7 mm mid stroke
        // PCB thickness 0.4 mm
        // tallest component 1.4 mm - use 1.5 mm
        // distance from PCBA to top of plastic: 4.1 + 0.15 + 0.7 = 4.95 mm - use 4.9 mm
        // thickness of plastic to clear components: 4.9 - 1.5 = 3.4 mm
        _d = 1.0;
        _pcbThickness = 0.4;
        _maxComponentHeight = 1.4;
        _midStroke = 0.7;
        _exposed = 0.15;
        _shaft = 4.1;
        _pcbOutlineTolerance = 0.2;
        _wallThickness = 2.0;
        _ledgeThickness = 1.0;
    }
    return self;
}

@end

@interface FDAppDelegate ()

@property (assign) IBOutlet NSPathControl *scriptPathControl;
@property (assign) IBOutlet NSPathControl *boardPathControl;
@property (assign) IBOutlet NSTextField *boardThicknessTextField;
@property (assign) IBOutlet FDBoardView *boardView;
@property NSString *scriptPath;
@property NSString *boardPath;
@property NSString *boardName;
@property FDBoard *board;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *boardPath = [userDefaults stringForKey:@"boardPath"];
    if (boardPath) {
        _boardPathControl.URL = [[NSURL alloc] initFileURLWithPath:boardPath];
    }
    
    NSString *boardThickness = [userDefaults stringForKey:@"boardThickness"];
    if (boardThickness) {
        _boardThicknessTextField.stringValue = boardThickness;
    }

    NSString *scriptPath = [userDefaults stringForKey:@"scriptPath"];
    if (scriptPath) {
        _scriptPathControl.URL = [[NSURL alloc] initFileURLWithPath:scriptPath];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *boardThickness = _boardThicknessTextField.stringValue;
    [userDefaults setObject:boardThickness forKey:@"boardThickness"];
    
    NSString *boardPath = _boardPathControl.URL.path;
    [userDefaults setObject:boardPath forKey:@"boardPath"];
    
    NSString *scriptPath = _scriptPathControl.URL.path;
    [userDefaults setObject:scriptPath forKey:@"scriptPath"];
}

- (NSBezierPath *)join:(NSBezierPath *)path
{
    static const double epsilon = 0.001;
    
    NSPoint last = NSMakePoint(0.123456, 0.123456);
    NSBezierPath *newPath = [NSBezierPath bezierPath];
    for (int i = 0; i < path.elementCount; ++i) {
        NSPoint	points[3];
        NSBezierPathElement kind = [path elementAtIndex:i associatedPoints:points];
        switch(kind) {
            default:
            case NSMoveToBezierPathElement:
                if ((fabs(last.x - points[0].x) > epsilon) || (fabs(last.y - points[0].y) > epsilon)) {
                    [newPath moveToPoint:points[0]];
                    last = points[0];
                    //                    NSLog(@"keeping move to %0.3f, %0.3f", points[0].x, points[0].y);
                } else {
                    //                    NSLog(@"discarding move to %0.3f, %0.3f", points[0].x, points[0].y);
                }
                break;
                
            case NSLineToBezierPathElement:
                [newPath lineToPoint:points[0]];
                last = points[0];
                break;
                
            case NSCurveToBezierPathElement:
                [newPath curveToPoint:points[2] controlPoint1:points[0] controlPoint2:points[1]];
                last = points[2];
                break;
                
            case NSClosePathBezierPathElement:
                [newPath closePath];
                break;
        }
    }
    return newPath;
}

- (NSBezierPath *)simplify:(NSBezierPath *)path distance:(CGFloat)distance
{
    NSPoint c = NSMakePoint(0.123456, 0.123456);
    NSBezierPath *newPath = [NSBezierPath bezierPath];
    for (int i = 0; i < path.elementCount; ++i) {
        NSPoint	points[3];
        NSBezierPathElement kind = [path elementAtIndex:i associatedPoints:points];
        switch(kind) {
            default:
            case NSMoveToBezierPathElement: {
                NSPoint p = points[0];
                [newPath moveToPoint:p];
                c = p;
            } break;
            
            case NSLineToBezierPathElement: {
                NSPoint p = points[0];
                double dx = c.x - p.x;
                double dy = c.y - p.y;
                double d = sqrt(dx * dx + dy * dy);
                if (d > distance) {
                    [newPath lineToPoint:p];
                    c = p;
                }
            } break;
            
            case NSCurveToBezierPathElement:
                [newPath curveToPoint:points[2] controlPoint1:points[0] controlPoint2:points[1]];
                c = points[2];
                break;
                
            case NSClosePathBezierPathElement:
                [newPath closePath];
                break;
        }
    }
    return newPath;
}

static float Det2(float x1, float x2, float y1, float y2) {
    return (x1 * y2 - y1 * x2);
}

#define min
static BOOL LineIntersection(NSPoint v1, NSPoint v2, NSPoint v3, NSPoint v4, NSPoint *r)
{
    float epsilon = 0.001f;
    float tolerance = 0.000001f;
    
    float a = Det2(v1.x - v2.x, v1.y - v2.y, v3.x - v4.x, v3.y - v4.y);
    if (fabs(a) < epsilon) return NO; // Lines are parallel
    
    float d1 = Det2(v1.x, v1.y, v2.x, v2.y);
    float d2 = Det2(v3.x, v3.y, v4.x, v4.y);
    float x = Det2(d1, v1.x - v2.x, d2, v3.x - v4.x) / a;
    float y = Det2(d1, v1.y - v2.y, d2, v3.y - v4.y) / a;
    
    if (x < MIN(v1.x, v2.x) - tolerance || x > MAX(v1.x, v2.x) + tolerance) return NO;
    if (y < MIN(v1.y, v2.y) - tolerance || y > MAX(v1.y, v2.y) + tolerance) return NO;
    if (x < MIN(v3.x, v4.x) - tolerance || x > MAX(v3.x, v4.x) + tolerance) return NO;
    if (y < MIN(v3.y, v4.y) - tolerance || y > MAX(v3.y, v4.y) + tolerance) return NO;
    
    *r = NSMakePoint(x, y);
    return YES;
}

#if 0
- (NSBezierPath *)simplify:(NSBezierPath *)path
{
    NSPoint c;
    NSBezierPath *newPath = [NSBezierPath bezierPath];
    for (int i = 0; i < path.elementCount; ++i) {
        NSPoint	points[3];
        NSBezierPathElement kind = [path elementAtIndex:i associatedPoints:points];
        switch(kind) {
            default:
            case NSMoveToBezierPathElement: {
                c = points[0];
                [newPath moveToPoint:c];
//                NSLog(@"keeping move to %0.3f, %0.3f", c.x, c.y);
            } break;
                
            case NSLineToBezierPathElement: {
                NSPoint p = points[0];
                if (![bounds containsPoint:p]) {
                    [newPath lineToPoint:points[0]];
//                    NSLog(@"keeping line to %0.3f, %0.3f", p.x, p.y);
                } else {
//                    NSLog(@"discarding line to %0.3f, %0.3f", p.x, p.y);
                }
            } break;
                
            case NSCurveToBezierPathElement: {
                NSPoint p = points[2];
                if (![bounds containsPoint:p]) {
                    [newPath curveToPoint:points[2] controlPoint1:points[0] controlPoint2:points[1]];
//                    NSLog(@"keeping curve to %0.3f, %0.3f", p.x, p.y);
                } else {
//                    NSLog(@"discarding curve to %0.3f, %0.3f", p.x, p.y);
                }
            } break;
                
            case NSClosePathBezierPathElement:
                [newPath closePath];
                break;
        }
    }
    return newPath;
}
#endif

- (NSBezierPath *)outline:(NSBezierPath *)path of:(NSBezierPath *)bounds inside:(BOOL)inside
{
    NSBezierPath *newPath = [NSBezierPath bezierPath];
    for (int i = 0; i < path.elementCount; ++i) {
        NSPoint	points[3];
        NSBezierPathElement kind = [path elementAtIndex:i associatedPoints:points];
        switch(kind) {
            default:
            case NSMoveToBezierPathElement: {
                NSPoint p = points[0];
                if ([bounds containsPoint:p] == inside) {
                    [newPath moveToPoint:p];
                    //                    NSLog(@"keeping move to %0.3f, %0.3f", p.x, p.y);
                } else {
                    //                    NSLog(@"discarding move to %0.3f, %0.3f", p.x, p.y);
                }
            } break;
                
            case NSLineToBezierPathElement: {
                NSPoint p = points[0];
                if ([bounds containsPoint:p] == inside) {
                    [newPath lineToPoint:points[0]];
                    //                    NSLog(@"keeping line to %0.3f, %0.3f", p.x, p.y);
                } else {
                    //                    NSLog(@"discarding line to %0.3f, %0.3f", p.x, p.y);
                }
            } break;
                
            case NSCurveToBezierPathElement: {
                NSPoint p = points[2];
                if ([bounds containsPoint:p] == inside) {
                    [newPath curveToPoint:points[2] controlPoint1:points[0] controlPoint2:points[1]];
                    //                    NSLog(@"keeping curve to %0.3f, %0.3f", p.x, p.y);
                } else {
                    //                    NSLog(@"discarding curve to %0.3f, %0.3f", p.x, p.y);
                }
            } break;
                
            case NSClosePathBezierPathElement:
                [newPath closePath];
                break;
        }
    }
    return newPath;
}

static const double EPSILON = 0.000001;

typedef struct {
    NSPoint first;
    NSPoint second;
} LineSegment;

double crossProduct(NSPoint a, NSPoint b) {
    return a.x * b.y - b.x * a.y;
}

bool isPointOnLine(LineSegment a, NSPoint b) {
    LineSegment aTmp = {.first = {0, 0}, .second = {.x = a.second.x - a.first.x, .y = a.second.y - a.first.y}};
    NSPoint bTmp = { .x = b.x - a.first.x, .y = b.y - a.first.y};
    double r = crossProduct(aTmp.second, bTmp);
    return fabs(r) < EPSILON;
}

bool isPointRightOfLine(LineSegment a, NSPoint b) {
    LineSegment aTmp = {.first = {0, 0}, .second = {.x = a.second.x - a.first.x, .y = a.second.y - a.first.y}};
    NSPoint bTmp = { .x = b.x - a.first.x, .y = b.y - a.first.y};
    return crossProduct(aTmp.second, bTmp) < 0;
}

bool lineSegmentTouchesOrCrossesLine(LineSegment a, LineSegment b) {
    return isPointOnLine(a, b.first) || isPointOnLine(a, b.second) || (isPointRightOfLine(a, b.first) ^ isPointRightOfLine(a, b.second));
}

bool doLinesIntersect(LineSegment a, LineSegment b) {
    return lineSegmentTouchesOrCrossesLine(a, b) && lineSegmentTouchesOrCrossesLine(b, a);
}

- (NSArray *)split:(NSBezierPath *)path withPath:splitPath
{
    NSMutableArray *paths = [NSMutableArray array];
    NSBezierPath *newPath = nil;
    NSPoint p0;
    for (int i = 0; i < path.elementCount; ++i) {
        if (newPath == nil) {
            newPath = [NSBezierPath bezierPath];
        }
        NSPoint	points[3];
        NSPoint p;
        NSBezierPathElement kind = [path elementAtIndex:i associatedPoints:points];
        switch(kind) {
            default:
            case NSMoveToBezierPathElement: {
                p = points[0];
                NSLog(@"move to %0.3f, %0.3f", p.x, p.y);
                if (newPath.elementCount > 1) {
                    [paths addObject:newPath];
                    newPath = nil;
                    newPath = [NSBezierPath bezierPath];
                }
                [newPath moveToPoint:p];
            } break;
                
            case NSLineToBezierPathElement: {
                p = points[0];
                NSLog(@"line to %0.3f, %0.3f", p.x, p.y);
                [newPath lineToPoint:p];
            } break;
                
            case NSCurveToBezierPathElement: {
                p = points[2];
                NSLog(@"curve to %0.3f, %0.3f", p.x, p.y);
                [newPath curveToPoint:p controlPoint1:points[0] controlPoint2:points[1]];
            } break;
                
            case NSClosePathBezierPathElement:
                NSLog(@"close");
                [newPath closePath];
                [paths addObject:newPath];
                newPath = nil;
                break;
        }
        if (newPath.elementCount == 1) {
            p0 = p;
        } else
        if (newPath.elementCount > 1) {
            static const double epsilon = 0.001;
            if ((fabs(p.x - p0.x) < epsilon) && (fabs(p.y - p0.y) < epsilon)) {
                [paths addObject:newPath];
                newPath = nil;
            }
        }
    }
    return paths;
}

- (NSBezierPath *)bezierPathForWires:(NSArray *)theWires
{
    static const double epsilon = 0.001;

    NSMutableArray *remaining = [NSMutableArray arrayWithArray:theWires];
    NSBezierPath *path = [NSBezierPath bezierPath];
    FDBoardWire *current = [remaining objectAtIndex:0];
//    NSLog(@"+ %0.3f, %0.3f - %0.3f, %0.3f", current.x1, current.y1, current.x2, current.y2);
    [remaining removeObject:current];
    [path appendBezierPath:current.bezierPath];
    double cx = current.x2;
    double cy = current.y2;
    while ([remaining count] > 0) {
        BOOL found = NO;
        for (FDBoardWire *candidate in remaining) {
            if ((fabs(candidate.x1 - cx) < epsilon) && (fabs(candidate.y1 - cy) < epsilon)) {
//                NSLog(@"> %0.3f, %0.3f - %0.3f, %0.3f", candidate.x1, candidate.y1, candidate.x2, candidate.y2);
                [remaining removeObject:candidate];
                [path appendBezierPath:candidate.bezierPath];
                cx = candidate.x2;
                cy = candidate.y2;
                found = YES;
                break;
            }
            if ((fabs(candidate.x2 - cx) < epsilon) && (fabs(candidate.y2 - cy) < epsilon)) {
//                NSLog(@"< %0.3f, %0.3f - %0.3f, %0.3f", candidate.x1, candidate.y1, candidate.x2, candidate.y2);
                [remaining removeObject:candidate];
                [path appendBezierPath:[candidate.bezierPath bezierPathByReversingPath]];
                cx = candidate.x1;
                cy = candidate.y1;
                found = YES;
                break;
            }
        }
        if (!found) {
            break;
        }
    }
    return [self join:path];
}

- (NSArray *)wiresForLayer:(int)layer
{
    NSMutableArray *wires = [NSMutableArray array];
    for (FDBoardWire *element in _board.container.wires) {
        if (element.layer == layer) {
            [wires addObject:element];
//            NSLog(@"Dimension %0.3f, %0.3f - %0.3f, %0.3f", element.x1, element.y1, element.x2, element.y2);
        }
    }
    return wires;
}


- (NSArray *)testPoints:(BOOL)mirrored
{
    NSMutableDictionary *signalFromElementPad = [NSMutableDictionary dictionary];
    for (FDBoardContactRef *contactRef in _board.container.contactRefs) {
        NSString *key = [NSString stringWithFormat:@"%@.%@", contactRef.element, contactRef.pad];
        [signalFromElementPad setObject:contactRef.signal forKey:key];
    }
    
    NSMutableArray *points = [NSMutableArray array];
    
    NSAffineTransform* transform = [NSAffineTransform transform];
    
    for (FDBoardInstance* instance in _board.container.instances) {
        FDBoardPackage *package = _board.packages[instance.package];
        if (package == nil) {
            continue;
        }
        
        if ([package.name isEqualToString:@"TARGET-PIN-1MM"] || [package.name isEqualToString:@"TP08R"] || [package.name isEqualToString:@"TC2030-MCP-NL"]) {
//            NSLog(@"%@ %0.3f, %0.3f", package.name, instance.x, instance.y);
            
            if (instance.mirror != mirrored) {
                continue;
            }
            
            NSAffineTransform* xform = [NSAffineTransform transform];
            [xform translateXBy:instance.x yBy:instance.y];
            if (instance.mirror) {
                [xform scaleXBy:-1 yBy:1];
            }
            [xform rotateByDegrees:instance.rotate];
            [transform prependTransform:xform];
            
            for (FDBoardSmd *smd in package.container.smds) {
                NSAffineTransform* xform = [NSAffineTransform transform];
                [xform translateXBy:smd.x yBy:smd.y];
                if (smd.mirror) {
                    [xform scaleXBy:-1 yBy:1];
                }
                [xform rotateByDegrees:smd.rotate];
                [transform prependTransform:xform];
  
                NSPoint p = [transform transformPoint:NSMakePoint(0, 0)];
                FDTestPoint *testPoint = [[FDTestPoint alloc] init];
                testPoint.x = p.x;
                testPoint.y = p.y;
                NSString *key = [NSString stringWithFormat:@"%@.%@", instance.name, smd.name];
                NSString *signal = signalFromElementPad[key];
                if (signal != nil) {
                    testPoint.name = signal;
                } else {
                    testPoint.name = instance.name;
                }
                [points addObject:testPoint];
                NSString *pogoDiameter = instance.attributes[@"POGO_DIAMETER"];
                if (pogoDiameter != nil) {
                    testPoint.diameter = [pogoDiameter doubleValue];
                }
                
                [xform invert];
                [transform prependTransform:xform];

//                NSLog(@"  %@ %0.3f, %0.3f %0.3f, %0.3f", smd.name, smd.x, smd.y, p.x, p.y);
            }
            
            [xform invert];
            [transform prependTransform:xform];
        }
    }

    return points;
}

- (NSString *)rhino3D:(NSBezierPath *)path z:(double)z name:(NSString *)name
{
    NSMutableString *lines = [NSMutableString string];
    [lines appendString:@"curves = []\n"];
    NSPoint c;
    for (int i = 0; i < path.elementCount; ++i) {
        NSPoint	points[3];
        NSBezierPathElement kind = [path elementAtIndex:i associatedPoints:points];
        switch(kind) {
            default:
            case NSMoveToBezierPathElement: {
                c = points[0];
            } break;
                
            case NSLineToBezierPathElement: {
                NSPoint p = points[0];
                if (!NSEqualPoints(c, p)) {
                    [lines appendFormat:@"curves.append(rs.AddLine((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f)))\n", c.x, c.y, z, p.x, p.y, z];
                }
                c = p;
            } break;
                
            case NSCurveToBezierPathElement: {
                NSPoint p0 = c; // starting point
                NSPoint p1 = points[0]; // first control point
                NSPoint p2 = points[1]; // second control point
                NSPoint p3 = points[2]; // ending point
                
                [lines appendFormat:@"cvs = []\n"];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p0.x, p0.y, z];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p1.x, p1.y, z];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p2.x, p2.y, z];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p3.x, p3.y, z];
                
                [lines appendFormat:@"knots = []\n"];
                for (int i = 0; i < 3; ++i) {
                    [lines appendFormat:@"knots.append(0.0)\n"];
                }
                for (int i = 0; i < 3; ++i) {
                    [lines appendFormat:@"knots.append(1.0)\n"];
                }
                
                [lines appendFormat:@"curve = rs.AddNurbsCurve(cvs, knots, 3)\n"];
                [lines appendString:@"curves.append(curve)\n"];
                
                c = p3;
            } break;
                
            case NSClosePathBezierPathElement:
                break;
        }
    }
    [lines appendFormat:@"%@ = rs.JoinCurves(curves, True)\n", name];
    return lines;
}

- (NSString *)eagle:(NSBezierPath *)bezierPath
{
    double tx = 0.0;
    double ty = 0.0;
    double flatness = [NSBezierPath defaultFlatness];
    [NSBezierPath setDefaultFlatness:0.01];
    NSBezierPath *path = [bezierPath bezierPathByFlatteningPath];
    [NSBezierPath setDefaultFlatness:flatness];
    NSMutableString *lines = [NSMutableString string];
    for (int i = 0; i < path.elementCount; ++i) {
        NSPoint	points[3];
        NSBezierPathElement kind = [path elementAtIndex:i associatedPoints:points];
        switch(kind) {
            default:
            case NSMoveToBezierPathElement: {
                NSPoint p = points[0];
                [lines appendFormat:@" (%0.3f %0.3f)", p.x + tx, p.y + ty];
            } break;
                
            case NSLineToBezierPathElement: {
                NSPoint p = points[0];
                [lines appendFormat:@" (%0.3f %0.3f)", p.x + tx, p.y + ty];
            } break;
                
            case NSCurveToBezierPathElement: {
                NSPoint p = points[2];
                [lines appendFormat:@" (%0.3f %0.3f)", p.x + tx, p.y + ty];
            } break;
                
            case NSClosePathBezierPathElement:
                break;
        }
    }
    return lines;
}

- (NSString *)derivedFileName:(NSString *)postfix bottom:(BOOL)bottom
{
    return [NSString stringWithFormat:@"%@/%@_%@_%@", _boardPath, [_boardName stringByDeletingPathExtension], bottom ? @"bottom" : @"top", postfix];
}

- (void)generateTestFixturePlastic:(FDFixtureProperties *)properties bottom:(BOOL)bottom testPoints:(NSArray *)testPoints display:(NSBezierPath *)display
{
    NSArray *wires = [self wiresForLayer:20]; // 20: "Dimension" (AKA Outline) layer
    NSBezierPath *path = [self bezierPathForWires:wires];
    
    FDClipper *clipper = [[FDClipper alloc] init];
    NSBezierPath *outline = [clipper path:path offset:properties.pcbOutlineTolerance];
    NSBezierPath *bounds = [clipper path:path offset:properties.wallThickness + properties.pcbOutlineTolerance];
    NSBezierPath *ledge = [clipper path:path offset:-(properties.ledgeThickness - properties.pcbOutlineTolerance)];
    
    const double r = properties.d / 2.0;
    
    double ceiling = properties.pcbThickness + properties.maxComponentHeight;
    double top = properties.pcbThickness + properties.midStroke + properties.exposed + properties.shaft;
    double pcb = properties.pcbThickness;
    if (bottom) {
        ceiling = -ceiling;
        top = -top;
        pcb = -pcb;
    }
    
    NSMutableString *lines = [NSMutableString string];
    [lines appendString:@"import Rhino\n"];
    [lines appendString:@"import scriptcontext\n"];
    [lines appendString:@"import rhinoscriptsyntax as rs\n"];
    
    // Rhino 3D test fixture outline
    [lines appendString:[self rhino3D:bounds z:0.0 name:@"bounds"]];
    [lines appendString:[self rhino3D:bounds z:top name:@"bounds2"]];
    [lines appendString:[self rhino3D:outline z:0.0 name:@"outline"]];
    [lines appendString:[self rhino3D:outline z:pcb name:@"outline2"]];
    [lines appendString:[self rhino3D:ledge z:pcb name:@"ledge"]];
    [lines appendString:[self rhino3D:ledge z:ceiling name:@"ledge2"]];
    
    [lines appendFormat:@"rs.AddPlanarSrf([bounds, outline])\n"];
    [lines appendFormat:@"boundsWall = rs.ExtrudeCurveStraight(bounds, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", 0.0, 0.0, 0.0, 0.0, 0.0, top];
    [lines appendFormat:@"outlineWall = rs.ExtrudeCurveStraight(outline, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", 0.0, 0.0, 0.0, 0.0, 0.0, pcb];
    [lines appendFormat:@"rs.AddPlanarSrf([outline2, ledge])\n"];
    [lines appendFormat:@"ledgeWall = rs.ExtrudeCurveStraight(ledge, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", 0.0, 0.0, pcb, 0.0, 0.0, ceiling];
    [lines appendFormat:@"out0 = rs.AddPlanarSrf([ledge2])\n"];
    [lines appendFormat:@"out1 = rs.AddPlanarSrf([bounds2])\n"];
    
    // Rhino 3D test point curves
    [lines appendString:@"probes = []\n"];
    for (FDTestPoint *testPoint in testPoints) {
        double x = testPoint.x;
        double y = testPoint.y;
        double z = ceiling;
        double tpr = r;
        if (testPoint.diameter != 0.0) {
            tpr = testPoint.diameter / 2.0;
        }
        [lines appendFormat:@"curve = rs.AddCircle3Pt((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", x - tpr, y, z, x + tpr, y, z, x, y + tpr, z];
        [lines appendFormat:@"probe = rs.ExtrudeCurveStraight(curve, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", x, y, z, x, y, top];
        [lines appendFormat:@"probes.append(probe)\n"];
        
        [lines appendFormat:@"result = rs.SplitBrep(out0, probe, False)\n"];
        [lines appendFormat:@"rs.DeleteObject(out0)\n"];
        [lines appendFormat:@"rs.DeleteObject(result[1])\n"];
        [lines appendFormat:@"out0 = result[0]\n"];
        
        [lines appendFormat:@"result = rs.SplitBrep(out1, probe, False)\n"];
        [lines appendFormat:@"rs.DeleteObject(out1)\n"];
        [lines appendFormat:@"rs.DeleteObject(result[1])\n"];
        [lines appendFormat:@"out1 = result[0]\n"];
    }
    
    NSLog(@"test fixture %@ plastic:\n%@", bottom ? @"bottom" : @"top", lines);
    NSString *fileName = [self derivedFileName:@"plate.py" bottom:bottom];
    [lines writeToFile:fileName atomically:NO encoding:NSUTF8StringEncoding error:nil];

    // fixture display outline
    [display appendBezierPath:outline];
    [display appendBezierPath:bounds];
    [display appendBezierPath:ledge];
    
    // fixture test point display
    for (FDTestPoint *testPoint in testPoints) {
        [display appendBezierPathWithOvalInRect:NSMakeRect(testPoint.x - r, testPoint.y - r, properties.d, properties.d)];
    }
}

- (void)generateTestFixtureSchematic:(FDFixtureProperties *)properties bottom:(BOOL)bottom testPoints:(NSArray *)testPoints
{
    NSMutableString *lines = [NSMutableString string];
    NSMutableDictionary *countByName = [NSMutableDictionary dictionary];
    double x = 2.0;
    double y = 8.0;
    for (FDTestPoint *testPoint in testPoints) {
        NSString *name = testPoint.name;
        NSNumber *count = countByName[name];
        [countByName setObject:[NSNumber numberWithInteger:count.integerValue + 1] forKey:name];
        if (count.integerValue > 0) {
            name = [NSString stringWithFormat:@"%@%ld", name, count.integerValue + 1];
            [countByName setObject:[NSNumber numberWithInteger:1] forKey:name];
        }
        testPoint.name = name;
        [lines appendFormat:@"add TARGET-PINPROBE-0985@firefly '%@' (%f %f);\n", name, x, y];
        y -= 0.4;
    }
    
    NSLog(@"test fixture top schematic:\n%@", lines);
    NSString *fileName = [self derivedFileName:@"plate_schematic.scr" bottom:bottom];
    [lines writeToFile:fileName atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

- (void)generateTestFixtureLayout:(FDFixtureProperties *)properties bottom:(BOOL)bottom testPoints:(NSArray *)testPoints
{
    NSMutableString *lines = [NSMutableString string];
    for (FDTestPoint *testPoint in testPoints) {
        [lines appendFormat:@"move '%@' (%f %f);\n", testPoint.name, testPoint.x, testPoint.y];
    }
    [lines appendString:@"LAYER bDocu;\n"];
    [lines appendString:@"SET WIRE_BEND 2;"];
    [lines appendString:@"WIRE 0.1"];
    NSBezierPath *outline = [self bezierPathForWires:[self wiresForLayer:20]]; // 20: "Dimension" layer
    [lines appendString:[self eagle:outline]];
    [lines appendString:@";\n"];
    
    NSLog(@"test fixture top layout:\n%@", lines);
    NSString *fileName = [self derivedFileName:@"plate_layout.scr" bottom:bottom];
    [lines writeToFile:fileName atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

- (void)generateTestFixture
{
    // fixture display path
    NSBezierPath *all = [NSBezierPath bezierPath];
    
    FDFixtureProperties *properties = [[FDFixtureProperties alloc] init];

    NSArray *topTestPoints = [self testPoints:NO];
    [self generateTestFixturePlastic:properties bottom:NO testPoints:topTestPoints display:all];
    [self generateTestFixtureSchematic:properties bottom:NO testPoints:topTestPoints];
    [self generateTestFixtureLayout:properties bottom:NO testPoints:topTestPoints];

    NSArray *bottomTestPoints = [self testPoints:YES];
    [self generateTestFixturePlastic:properties bottom:YES testPoints:bottomTestPoints display:all];
    [self generateTestFixtureSchematic:properties bottom:YES testPoints:bottomTestPoints];
    [self generateTestFixtureLayout:properties bottom:YES testPoints:bottomTestPoints];
    
    _boardView.fixturePath = all;
}

- (IBAction)convert:(id)sender
{
    NSString *scriptPath = _scriptPathControl.URL.path;
    if (!scriptPath) {
        return;
    }
    _scriptPath = scriptPath;
    NSString *boardPath = _boardPathControl.URL.path;
    if (!boardPath) {
        return;
    }
    _boardPath = [boardPath stringByDeletingLastPathComponent];
    _boardName = [boardPath lastPathComponent];
    
    NSString *path = [_boardPath stringByAppendingPathComponent:_boardName];
    NSError *error = nil;
    NSString *xml = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];

    _board = [[FDBoard alloc] init];
    _board.thickness = [[_boardThicknessTextField stringValue] doubleValue];
    [self loadDocument:document container:_board.container];
    
    [self generateTestFixture];
    
    _boardView.board = _board;
    [_boardView setNeedsDisplay:YES];
    
    FDRhino *rhino = [[FDRhino alloc] init];
    rhino.board = _board;
    rhino.lines = [NSMutableString stringWithContentsOfFile:[[_scriptPath stringByAppendingPathComponent:@"3d"] stringByAppendingPathExtension:@"py"] encoding:NSUTF8StringEncoding error:&error];
    [rhino convert];
    NSString *output = [[[_scriptPath stringByAppendingPathComponent:_boardName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"py"];
    [rhino.lines writeToFile:output atomically:NO encoding:NSUTF8StringEncoding error:&error];
}

- (void)loadWire:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardWire *wire = [[FDBoardWire alloc] init];
    wire.x1 = [[[element attributeForName:@"x1"] stringValue] doubleValue];
    wire.y1 = [[[element attributeForName:@"y1"] stringValue] doubleValue];
    wire.x2 = [[[element attributeForName:@"x2"] stringValue] doubleValue];
    wire.y2 = [[[element attributeForName:@"y2"] stringValue] doubleValue];
    wire.width = [[[element attributeForName:@"width"] stringValue] doubleValue];
    wire.curve = [[[element attributeForName:@"curve"] stringValue] doubleValue];
    wire.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    [container.wires addObject:wire];
}

- (void)loadPolygon:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardPolygon *polygon = [[FDBoardPolygon alloc] init];
    polygon.width = [[[element attributeForName:@"width"] stringValue] doubleValue];
    polygon.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    NSError *error = nil;
    NSArray *elements = [element objectsForXQuery:@"vertex" error:&error];
    for (NSXMLElement *element in elements) {
        FDBoardVertex *vertex = [[FDBoardVertex alloc] init];
        vertex.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
        vertex.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
        vertex.curve = [[[element attributeForName:@"curve"] stringValue] doubleValue];
        [polygon.vertices addObject:vertex];
    }
    [container.polygons addObject:polygon];
}

- (void)loadVia:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardVia *via = [[FDBoardVia alloc] init];
    via.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    via.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    via.drill = [[[element attributeForName:@"drill"] stringValue] doubleValue];
    [container.vias addObject:via];
}

- (void)loadHole:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardHole *hole = [[FDBoardHole alloc] init];
    hole.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    hole.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    hole.drill = [[[element attributeForName:@"drill"] stringValue] doubleValue];
    [container.holes addObject:hole];
}

- (void)loadCircle:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardCircle *circle = [[FDBoardCircle alloc] init];
    circle.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    circle.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    circle.radius = [[[element attributeForName:@"radius"] stringValue] doubleValue];
    circle.width = [[[element attributeForName:@"width"] stringValue] doubleValue];
    circle.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    [container.circles addObject:circle];
}

- (void)parseRot:(NSString *)rot mirror:(BOOL *)mirror rotate:(double *)rotate
{
    if (rot != nil) {
        if ([rot hasPrefix:@"M"]) {
            *mirror = YES;
            *rotate = [[rot substringFromIndex:2] doubleValue];
        } else {
            *mirror = NO;
            *rotate = [[rot substringFromIndex:1] doubleValue];
        }
    }
}

- (void)loadSmd:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardSmd *smd = [[FDBoardSmd alloc] init];
    smd.name = [[element attributeForName:@"name"] stringValue];
    smd.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    smd.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    smd.dx = [[[element attributeForName:@"dx"] stringValue] doubleValue];
    smd.dy = [[[element attributeForName:@"dy"] stringValue] doubleValue];
    smd.roundness = [[[element attributeForName:@"roundness"] stringValue] doubleValue];
    NSString *rot = [[element attributeForName:@"rot"] stringValue];
    BOOL mirror = NO;
    double rotate = 0.0;
    [self parseRot:rot mirror:&mirror rotate:&rotate];
    smd.mirror = mirror;
    smd.rotate = rotate;
    smd.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    [container.smds addObject:smd];
}

- (void)loadPad:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardPad *pad = [[FDBoardPad alloc] init];
    pad.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    pad.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    pad.drill = [[[element attributeForName:@"drill"] stringValue] doubleValue];
    NSString *rot = [[element attributeForName:@"rot"] stringValue];
    BOOL mirror = NO;
    double rotate = 0.0;
    [self parseRot:rot mirror:&mirror rotate:&rotate];
    pad.mirror = mirror;
    pad.rotate = rotate;
    pad.shape = [[element attributeForName:@"shape"] stringValue];
    [container.pads addObject:pad];
}

- (void)loadContactRef:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardContactRef *contactRef = [[FDBoardContactRef alloc] init];
    contactRef.signal = [[((NSXMLElement *)element.parent) attributeForName:@"name"] stringValue];
    contactRef.element = [[element attributeForName:@"element"] stringValue];
    contactRef.pad = [[element attributeForName:@"pad"] stringValue];
    [container.contactRefs addObject:contactRef];
}

- (void)loadInstance:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardInstance *instance = [[FDBoardInstance alloc] init];
    instance.name = [[element attributeForName:@"name"] stringValue];
    instance.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    instance.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    NSString *rot = [[element attributeForName:@"rot"] stringValue];
    BOOL mirror = NO;
    double rotate = 0.0;
    [self parseRot:rot mirror:&mirror rotate:&rotate];
    instance.mirror = mirror;
    instance.rotate = rotate;
    instance.library = [[element attributeForName:@"library"] stringValue];
    instance.package = [[element attributeForName:@"package"] stringValue];
    for (NSXMLElement *attributeElement in [element elementsForName:@"attribute"]) {
        NSString *name = [[attributeElement attributeForName:@"name"] stringValue];
        NSString *value = [[attributeElement attributeForName:@"value"] stringValue];
        instance.attributes[name] = value;
    }
    [container.instances addObject:instance];
}

- (FDBoardPackage *)loadPackage:(NSXMLElement *)element
{
    FDBoardPackage *package = [[FDBoardPackage alloc] init];
    package.name = [[element attributeForName:@"name"] stringValue];
    NSError *error = nil;
    NSArray *elements = [element objectsForXQuery:@"*" error:&error];
    [self loadElements:elements container:package.container];
    return package;
}

- (void)loadElements:(NSArray *)elements container:(FDBoardContainer *)container
{
    for (NSXMLElement *element in elements) {
        NSString *name = [element localName];
        if ([@"wire" isEqualToString:name]) {
            [self loadWire:container element:element];
        } else
        if ([@"polygon" isEqualToString:name]) {
            [self loadPolygon:container element:element];
        } else
        if ([@"hole" isEqualToString:name]) {
            [self loadHole:container element:element];
        } else
        if ([@"circle" isEqualToString:name]) {
            [self loadCircle:container element:element];
        } else
        if ([@"smd" isEqualToString:name]) {
            [self loadSmd:container element:element];
        } else
        if ([@"pad" isEqualToString:name]) {
            [self loadPad:container element:element];
        } else
        if ([@"contactref" isEqualToString:name]) {
            [self loadContactRef:container element:element];
        }
    }
}

- (void)loadDocument:(NSXMLDocument *)document container:(FDBoardContainer *)container
{
    NSError *error = nil;
    NSArray *plainElements = [document objectsForXQuery:@"./eagle/drawing/board/plain/*" error:&error];
    [self loadElements:plainElements container:container];
    NSArray *signalElements = [document objectsForXQuery:@"./eagle/drawing/board/signals/signal/*" error:&error];
    [self loadElements:signalElements container:container];
    NSArray *wireElements = [document objectsForXQuery:@"./eagle/drawing/board/signals/signal/wire" error:&error];
    for (NSXMLElement *wireElement in wireElements) {
        [self loadWire:container element:wireElement];
    }
    NSArray *viaElements = [document objectsForXQuery:@"./eagle/drawing/board/signals/signal/via" error:&error];
    for (NSXMLElement *viaElement in viaElements) {
        [self loadVia:container element:viaElement];
    }
    NSArray *packageElements = [document objectsForXQuery:@"./eagle/drawing/board/libraries/library/packages/package" error:&error];
    for (NSXMLElement *packageElement in packageElements) {
        FDBoardPackage *package = [self loadPackage:packageElement];
        _board.packages[package.name] = package;
    }
    NSArray *instanceElements = [document objectsForXQuery:@"./eagle/drawing/board/elements/element" error:&error];
    for (NSXMLElement *instanceElement in instanceElements) {
        [self loadInstance:container element:instanceElement];
    }
}

@end
