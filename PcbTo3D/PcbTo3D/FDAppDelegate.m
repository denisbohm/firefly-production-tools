//
//  FDAppDelegate.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/6/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"
#import "FDBoardView.h"
#import "FDRhino.h"

#import <DKDrawKit/DKDrawKit.h>

@interface FDTestPoint : NSObject
@property double x;
@property double y;
@property NSString *name;
@end

@implementation FDTestPoint
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


- (NSArray *)testPoints
{
    NSMutableArray *points = [NSMutableArray array];
    
    NSAffineTransform* transform = [NSAffineTransform transform];
    
    for (FDBoardInstance* instance in _board.container.instances) {
        FDBoardPackage *package = _board.packages[instance.package];
        if (package == nil) {
            continue;
        }
        
        if ([package.name isEqualToString:@"TP08R"] || [package.name isEqualToString:@"TC2030-MCP-NL"]) {
            NSLog(@"%@ %0.3f, %0.3f", package.name, instance.x, instance.y);
            
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
                testPoint.name = [NSString stringWithFormat:@"%@_%@", instance.name, smd.name];
                [points addObject:testPoint];
                
                [xform invert];
                [transform prependTransform:xform];

                NSLog(@"  %@ %0.3f, %0.3f %0.3f, %0.3f", smd.name, smd.x, smd.y, p.x, p.y);
            }
            
            [xform invert];
            [transform prependTransform:xform];
        }
    }

    return points;
}

- (NSString *)rhino3D:(NSBezierPath *)path
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
                    [lines appendFormat:@"curves.append(rs.AddLine((%f, %f, 0), (%f, %f, 0)))\n", c.x, c.y, p.x, p.y];
                }
                c = p;
            } break;
                
            case NSCurveToBezierPathElement: {
                NSPoint p0 = c; // starting point
                NSPoint p1 = points[0]; // first control point
                NSPoint p2 = points[1]; // second control point
                NSPoint p3 = points[2]; // ending point
                
                [lines appendFormat:@"cvs = []\n"];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, 0.0))\n", p0.x, p0.y];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, 0.0))\n", p1.x, p1.y];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, 0.0))\n", p2.x, p2.y];
                [lines appendFormat:@"cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, 0.0))\n", p3.x, p3.y];
                
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
    [lines appendFormat:@"rs.JoinCurves(curves, True)\n"];
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

- (void)generateTestFixture
{
    // fixture display path
    NSBezierPath *all = [NSBezierPath bezierPath];

    NSArray *wires = [self wiresForLayer:20]; // 20: "Dimension" (AKA Outline) layer
    NSBezierPath *path = [self bezierPathForWires:wires];
    // 0.2 mm margin for test fixture
    NSBezierPath *outline = [self outline:[path strokedPathWithStrokeWidth:0.2] of:path inside:NO];
    NSBezierPath *simple = [self simplify:outline distance:2.0];
    NSBezierPath *bounds = [self outline:[simple strokedPathWithStrokeWidth:2.0] of:simple inside:NO];
    NSBezierPath *ledge = [self outline:[simple strokedPathWithStrokeWidth:1.0] of:simple inside:YES];

    // fixture display outline
    [all appendBezierPath:outline];
    [all appendBezierPath:bounds];
    [all appendBezierPath:ledge];
    
    NSArray *testPoints = [self testPoints];
    
    // 1 mm diameter mounting hole for Mill-Max Spring Loaded Pin 0985-0-15-20-71-14-11-0
    const double d = 1.0;
    const double r = d / 2.0;
    
    // fixture test point display
    for (FDTestPoint *testPoint in testPoints) {
        [all appendBezierPathWithOvalInRect:NSMakeRect(testPoint.x - r, testPoint.y - r, d, d)];
    }
    
    NSMutableString *lines = [NSMutableString string];
    [lines appendString:@"import Rhino\n"];
    [lines appendString:@"import scriptcontext\n"];
    [lines appendString:@"import rhinoscriptsyntax as rs\n"];

    // Rhino 3D test fixture outline
    [lines appendString:[self rhino3D:ledge]];
    [lines appendString:[self rhino3D:outline]];
    [lines appendString:[self rhino3D:bounds]];
    
    // Rhino 3D test point curves
    [lines appendString:@"curves = []\n"];
    for (FDTestPoint *testPoint in testPoints) {
        double x = testPoint.x;
        double y = testPoint.y;
        [lines appendFormat:@"curves.append(rs.AddCircle3Pt((%f, %f, 0), (%f, %f, 0), (%f, %f, 0)))\n", x - r, y, x + r, y, x, y + r];
    }
    
    // Eagle CAD test points
    int index = 0;
    for (FDTestPoint *testPoint in testPoints) {
        [lines appendFormat:@"add TARGET-PINPROBE-0985@firefly J%u (%f %f);\n", index, testPoint.x, testPoint.y];
        ++index;
    }
    index = 0;
    for (FDTestPoint *testPoint in testPoints) {
        [lines appendFormat:@"move J%u (%f %f);\n", index, testPoint.x, testPoint.y];
        ++index;
    }
    [lines appendString:@"LAYER bDocu;\n"];
    [lines appendString:@"SET WIRE_BEND 2;"];
    [lines appendString:@"WIRE 0.1"];
    [lines appendString:[self eagle:outline]];
    [lines appendString:@";\n"];
    
    NSLog(@"fixture CAD:\n%@", lines);
    
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
