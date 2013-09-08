//
//  FDRhino.h
//  PcbTo3D
//
//  Created by Denis Bohm on 9/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDBoard.h"

#import <Cocoa/Cocoa.h>

@interface FDRhino : NSObject

@property FDBoard *board;
@property NSMutableString *lines;

- (void)convert;

@end
