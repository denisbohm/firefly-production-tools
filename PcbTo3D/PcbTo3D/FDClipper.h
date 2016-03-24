//
//  FDClipper.h
//  PcbTo3D
//
//  Created by Denis Bohm on 11/21/15.
//  Copyright © 2015 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDClipper : NSObject

- (NSBezierPath *)path:(NSBezierPath *)path offset:(CGFloat)offset;

@end
