//
//  FDAppDelegate.m
//  Firefly Test Pool
//
//  Created by Denis Bohm on 4/18/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDAppDelegate.h"

#import "FDPoolManager.h"
#import "FDPoolTableViewDataSource.h"

@interface FDAppDelegate () <NSTableViewDelegate>

@property FDPoolManager* poolManager;

@property (assign) IBOutlet NSTableView* poolTableView;

@property BOOL selected;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    _poolManager = [[FDPoolManager alloc] initWithTableView:_poolTableView];
    
    _poolTableView.delegate = self;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    self.selected = _poolTableView.selectedRowIndexes.count > 0;
}

- (IBAction)openPool:(id)sender
{
    [_poolManager openPool];
}

- (IBAction)closePool:(id)sender
{
    [_poolManager closePool];
}

- (IBAction)rescanPool:(id)sender
{
    [_poolManager rescanPool];
}

- (IBAction)refreshPool:(id)sender
{
    [_poolManager refreshPool];
}

- (IBAction)storagePool:(id)sender
{
    [_poolManager storagePool];
}

- (IBAction)indicatePool:(id)sender
{
    [_poolManager indicatePool];
}

- (IBAction)updatePool:(id)sender
{
    [_poolManager updatePool];
}

- (IBAction)resetPool:(id)sender
{
    [_poolManager resetPool];
}

- (IBAction)setTimePool:(id)sender
{
    [_poolManager setTimePool];
}

@end
