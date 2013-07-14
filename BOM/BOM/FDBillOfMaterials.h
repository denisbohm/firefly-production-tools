//
//  FDBillOfMaterials.h
//  enclose
//
//  Created by Denis Bohm on 2/10/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDBillOfMaterials : NSObject

@property NSString *schematicPath;

- (void)read;
- (void)exportForDigikey;
- (void)exportForMouser;
- (void)exportForArrow;
- (void)exportForRichardsonRFPD;
- (void)exportForScreamingCircuits;

@end
