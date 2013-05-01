//
//  FDExecutable.h
//  Sync
//
//  Created by Denis Bohm on 4/26/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDExecutableFunction : NSObject

@property NSString *name;
@property uint32_t address;

@end

typedef enum {
    FDExecutableSectionTypeProgram, FDExecutableSectionTypeData
} FDExecutableSectionType;

@interface FDExecutableSection : NSObject

@property FDExecutableSectionType type;
@property uint32_t address;
@property NSData *data;

@end

@interface FDExecutable : NSObject

@property NSArray *sections;
@property NSMutableDictionary *functions;

- (void)load:(NSString *)filename;

@end
