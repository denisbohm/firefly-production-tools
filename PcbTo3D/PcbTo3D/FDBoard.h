//
//  FDBoard.h
//  PcbTo3D
//
//  Created by Denis Bohm on 9/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDBoardWire : NSObject
@property double x1;
@property double y1;
@property double x2;
@property double y2;
@property double width;
@property double curve;
@property int layer;
@end

@interface FDBoardVertex : NSObject
@property double x;
@property double y;
@property double curve;
@end

@interface FDBoardPolygon : NSObject
@property double width;
@property int layer;
@property NSMutableArray *vertices;
@end

@interface FDBoardVia : NSObject
@property double x;
@property double y;
@property double drill;
@end

@interface FDBoardCircle : NSObject
@property double x;
@property double y;
@property double radius;
@property double width;
@property int layer;
@end

@interface FDBoardHole : NSObject
@property double x;
@property double y;
@property double drill;
@end

@interface FDBoardSmd : NSObject
@property double x;
@property double y;
@property double dx;
@property double dy;
@property double roundness;
@property BOOL mirror;
@property double rotate;
@property int layer;
@end

@interface FDBoardPad : NSObject
@property double x;
@property double y;
@property double drill;
@property BOOL mirror;
@property double rotate;
@property NSString *shape;
@end

@interface FDBoardInstance : NSObject
@property double x;
@property double y;
@property BOOL mirror;
@property double rotate;
@property NSString *library;
@property NSString *package;
@end

@interface FDBoardContainer : NSView
@property NSMutableArray *wires;
@property NSMutableArray *polygons;
@property NSMutableArray *vias;
@property NSMutableArray *circles;
@property NSMutableArray *holes;
@property NSMutableArray *smds;
@property NSMutableArray *pads;
@property NSMutableArray *instances;
@end

@interface FDBoardPackage : NSView
@property NSString *name;
@property FDBoardContainer *container;
@end

@interface FDBoard : NSObject

@property NSMutableDictionary *packages;
@property FDBoardContainer *container;

+ (NSPoint)getCenterOfCircleX1:(double)x1 y1:(double)y1 x2:(double)x2 y2:(double)y2 angle:(double)angle;

@end
