//
//  FDClipper.h
//  PcbTo3D
//
//  Created by Denis Bohm on 11/21/15.
//  Copyright © 2015 Firefly Design. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface FDClipper : NSObject

- (nonnull NSBezierPath *)path:(nonnull NSBezierPath *)path offset:(CGFloat)offset;

@end
