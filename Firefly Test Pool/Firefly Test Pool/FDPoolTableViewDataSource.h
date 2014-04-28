//
//  FDPoolTableViewDataSource.h
//  Firefly Test Pool
//
//  Created by Denis Bohm on 4/18/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;
@class FDExecutor;
@class FDPoolMember;

@interface FDPoolTableViewDataSource : NSObject <NSTableViewDataSource>

@property NSMutableArray *members;

- (FDPoolMember *)memberForPeripheral:(CBPeripheral *)peripheral;
- (FDPoolMember *)memberForExecutor:(FDExecutor *)executor;
- (NSInteger)addMember:(FDPoolMember *)member;
- (NSInteger)getMemberIndex:(FDPoolMember *)member;
- (FDPoolMember *)getMemberAtIndex:(NSInteger)index;
- (void)removeAllMembers;

@end
