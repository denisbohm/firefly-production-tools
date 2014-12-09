//
//  FDFireflyIceMint.h
//  FireflyFlash
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <FireflyProduction/FDSerialWireDebugTask.h>

#import <Foundation/Foundation.h>

@interface FDFireflyIceMint : FDSerialWireDebugTask

+ (NSData *)loadConstants:(NSString *)name searchPath:(NSString *)searchPath;

@end
