//
//  FDPoolManager.h
//  Firefly Test Pool
//
//  Created by Denis Bohm on 4/18/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

@class FDIntelHex;
@class FDPoolTableViewDataSource;

@interface FDPoolManager : NSObject

- (id)initWithTableView:(NSTableView *)tableView;

- (void)openPool;
- (void)closePool;
- (void)rescanPool;

- (void)indicatePool;
- (void)refreshPool;
- (void)updatePool:(FDIntelHex *)firmware;
- (void)erasePool;
- (void)resetPool;
- (void)setTimePool;
- (void)storagePool;

@property CBUUID *serviceUUID;

@end
