//
//  FDBoardView.h
//  PcbTo3D
//
//  Created by Denis Bohm on 9/6/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDBoard.h"

#import <Cocoa/Cocoa.h>

@interface FDBoardView : NSView

@property FDBoard *board;
@property NSBezierPath *fixturePath;

@end