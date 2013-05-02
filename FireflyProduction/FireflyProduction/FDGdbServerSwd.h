//
//  FDGdbServerSwd.h
//  Sync
//
//  Created by Denis Bohm on 4/28/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDGdbServer.h"

#import <ARMSerialWireDebug/FDSerialWireDebug.h>

@interface FDGdbServerSwd : NSObject <FDGdbServerDelegate>

@property FDGdbServer *gdbServer;
@property FDSerialWireDebug *serialWireDebug;
@property BOOL halted;

@end
