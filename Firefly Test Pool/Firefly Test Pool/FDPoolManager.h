//
//  FDPoolManager.h
//  Firefly Test Pool
//
//  Created by Denis Bohm on 4/18/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDPoolTableViewDataSource;

@interface FDPoolManager : NSObject

- (id)initWithTableView:(NSTableView *)tableView;

- (void)openPool;
- (void)closePool;
- (void)rescanPool;

- (void)indicatePool;
- (void)refreshPool;
- (void)updatePool;
- (void)resetPool;
- (void)setTimePool;
- (void)storagePool;

@end
