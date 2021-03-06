//
//  FDExecutable.h
//  Sync
//
//  Created by Denis Bohm on 4/26/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDExecutableSymbol : NSObject

@property NSString *name;
@property uint32_t address;

@end

@interface FDExecutableFunction : FDExecutableSymbol

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
@property NSMutableDictionary *globals;

- (void)load:(NSString *)filename;

// combine sections withing the given address range into sections that
// start and stop on page boundaries
- (NSArray *)combineSectionsType:(FDExecutableSectionType)type
                         address:(uint32_t)address
                          length:(uint32_t)length
                        pageSize:(uint32_t)pageSize;

- (NSArray *)combineAllSectionsType:(FDExecutableSectionType)type
                            address:(uint32_t)address
                             length:(uint32_t)length
                           pageSize:(uint32_t)pageSize;

@end
