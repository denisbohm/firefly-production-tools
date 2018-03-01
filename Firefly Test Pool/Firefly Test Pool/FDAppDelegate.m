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

#import <FireflyDevice/FDFirmwareUpdateTask.h>
#import <FireflyDevice/FDIntelHex.h>

@interface FDAppDelegate () <NSTableViewDelegate>

@property IBOutlet NSPanel *preferencesPanel;

@property IBOutlet NSTextField *serviceTextField;
@property IBOutlet NSTextField *firmwareNameTextField;
@property IBOutlet NSPathControl *searchPathControl;
@property BOOL userDefaultsLoaded;

@property FDPoolManager* poolManager;

@property (assign) IBOutlet NSTableView* poolTableView;

@property BOOL selected;

@end

@implementation FDAppDelegate

- (void)loadUserDefaults
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:@"searchPath"]) {
        @try {
            NSString *searchPath = [userDefaults objectForKey:@"searchPath"];
            if (searchPath != nil) {
                NSURL *URL = [NSURL fileURLWithPath:searchPath];
                if ([URL isFileURL]) {
                    _searchPathControl.URL = URL;
                }
            }
        } @catch (NSException *e) {
            NSLog(@"cannot set search path: %@", e);
        }
    }
    if ([userDefaults objectForKey:@"firmwareName"]) {
        _firmwareNameTextField.stringValue = [userDefaults stringForKey:@"firmwareName"];
    }
    if ([userDefaults objectForKey:@"bleServiceUUID"]) {
        _serviceTextField.stringValue = [userDefaults stringForKey:@"bleServiceUUID"];
    }
    _userDefaultsLoaded = YES;
}

- (void)saveUserDefaults
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:_serviceTextField.stringValue forKey:@"bleServiceUUID"];
    [userDefaults setObject:_firmwareNameTextField.stringValue forKey:@"firmwareName"];
    if ([_searchPathControl.URL isFileURL]) {
        [userDefaults setObject:[_searchPathControl.URL path] forKey:@"searchPath"];
    } else {
        [userDefaults removeObjectForKey:@"searchPath"];
    }
}

- (IBAction)resourceChanged:(id)sender
{
    if (_userDefaultsLoaded) {
        [self saveUserDefaults];
        _poolManager.serviceUUID = [CBUUID UUIDWithString:_serviceTextField.stringValue];
    }
}

- (IBAction)showPreferences:(id)sender
{
    [_preferencesPanel setIsVisible:YES];
}

- (IBAction)resetToDefaults:(id)sender
{
    NSString *searchPath = [NSString stringWithFormat:@"%@/sandbox/denisbohm/firefly-ice-firmware/release", NSHomeDirectory()];
    NSURL *URL = [NSURL fileURLWithPath:searchPath isDirectory:YES];
    _searchPathControl.URL = URL;
    _firmwareNameTextField.stringValue = @"FireflyIce";
    _serviceTextField.stringValue = @"310a0001-1b95-5091-b0bd-b7a681846399";
    
    [self saveUserDefaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [self loadUserDefaults];
    
    _poolManager = [[FDPoolManager alloc] initWithTableView:_poolTableView];
    _poolManager.serviceUUID = [CBUUID UUIDWithString:_serviceTextField.stringValue];
    _poolTableView.delegate = self;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    return YES;
}

- (NSString *)getHexPath:(NSString *)name type:(NSString *)type searchPath:(NSString *)searchPath
{
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:searchPath error:nil];
    NSArray *files = [allFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(self BEGINSWITH %@) AND (self ENDSWITH '.hex')", name]];
    files = [files sortedArrayUsingComparator: ^(id oa, id ob) {
        NSString *a = (NSString *)oa;
        NSString *b = (NSString *)ob;
        return [a compare:b options:NSNumericSearch];
    }];
    if (files.count > 0) {
        return [searchPath stringByAppendingPathComponent:files.lastObject];
    }
    
    return [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:@"hex"];
}

- (FDIntelHex *)getFirmware
{
    NSString *searchPath = _searchPathControl.URL.path;
    NSString *path = [self getHexPath:_firmwareNameTextField.stringValue type:@"THUMB Flash Release" searchPath:searchPath];
    if (path != nil) {
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:nil];
        return [FDIntelHex intelHex:content address:0 length:0];
    }
    NSArray *versions = [FDFirmwareUpdateTask loadAllFirmwareVersions:_firmwareNameTextField.stringValue];
    if (versions.count <= 0) {
        @throw [NSException exceptionWithName:@"CanNotFindFirmware" reason:@"Can not find firmware" userInfo:nil];
    }
    return versions.lastObject;
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
    [_poolManager updatePool:[self getFirmware]];
}

- (IBAction)erasePool:(id)sender
{
    [_poolManager erasePool];
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
