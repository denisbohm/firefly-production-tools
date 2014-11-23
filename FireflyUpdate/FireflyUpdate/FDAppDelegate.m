//
//  FDAppDelegate.m
//  FireflyUpdate
//
//  Created by Denis Bohm on 10/8/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDAppDelegate.h"

#import "FDUSBPort.h"

#import <FireflyDevice/FDBinary.h>
#import <FireflyDevice/FDFireflyIce.h>
#import <FireflyDevice/FDFireflyIceChannelBLE.h>
#import <FireflyDevice/FDFireflyIceChannelUSB.h>
#import <FireflyDevice/FDFireflyIceCoder.h>
#import <FireflyDevice/FDFireflyIceSimpleTask.h>
#import <FireflyDevice/FDFirmwareUpdateTask.h>
#import <FireflyDevice/FDHelloTask.h>
#import <FireflyDevice/FDIntelHex.h>
#import <FireflyDevice/FDUSBHIDMonitor.h>

@interface FDAppDelegate () <FDUSBHIDMonitorDelegate>

@property (weak) IBOutlet NSWindow *window;
@property IBOutlet NSPanel *preferencesPanel;

@property IBOutlet NSTextField *usbVendorIdTextField;
@property IBOutlet NSTextField *usbProductIdTextField;
@property IBOutlet NSTextField *firmwareNameTextField;
@property IBOutlet NSPathControl *searchPathControl;

@property NSArray *usbPorts;

@property FDUSBHIDMonitor *usbMonitor;

@property BOOL userDefaultsLoaded;

@end

@implementation FDAppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

+ (uint16_t)scanHexUInt16:(NSString *)text
{
    unsigned int value = 0;
    [[NSScanner scannerWithString:text] scanHexInt:&value];
    return value;
}

- (NSView *)viewWithIdentifier:(NSString *)identifier inArray:(NSArray *)views
{
    for (NSView *view in views) {
        if ([view.identifier isEqualToString:identifier]) {
            return view;
        }
    }
    return nil;
}

- (NSMutableArray *)allSubviewsInView:(NSView *)parentView {
    NSMutableArray *allSubviews     = [[NSMutableArray alloc] initWithObjects: nil];
    NSMutableArray *currentSubviews = [[NSMutableArray alloc] initWithObjects: parentView, nil];
    NSMutableArray *newSubviews     = [[NSMutableArray alloc] initWithObjects: parentView, nil];
    
    while (newSubviews.count) {
        [newSubviews removeAllObjects];
        
        for (NSView *view in currentSubviews) {
            for (NSView *subview in view.subviews) [newSubviews addObject:subview];
        }
        
        [currentSubviews removeAllObjects];
        [currentSubviews addObjectsFromArray:newSubviews];
        [allSubviews addObjectsFromArray:newSubviews];
        
    }
    
    return allSubviews;
}

- (void)saveLocations
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    for (FDUSBPort *usbPort in _usbPorts) {
        if (usbPort.location != nil) {
            [userDefaults setObject:usbPort.location forKey:usbPort.identifier];
        }
    }
}

- (void)loadLocations
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    for (FDUSBPort *usbPort in _usbPorts) {
        NSObject *location = [userDefaults objectForKey:usbPort.identifier];
        if (location != nil) {
            usbPort.location = location;
        }
    }
}

- (void)saveUserDefaults
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:_usbVendorIdTextField.stringValue forKey:@"usbVendorID"];
    [userDefaults setObject:_usbProductIdTextField.stringValue forKey:@"usbProductID"];
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
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSMutableArray *usbPorts = [NSMutableArray array];
    NSArray *windowViews = [self allSubviewsInView:_window.contentView];
    for (int i = 1; i <= 16; ++i) {
        NSString *identifier = [NSString stringWithFormat:@"usbPort%d", i];
        NSBox *box = (NSBox *)[self viewWithIdentifier:identifier inArray:windowViews];
        if (box == nil) {
            break;
        }
        FDUSBPort *usbPort = [[FDUSBPort alloc] init];
        usbPort.identifier = identifier;
        NSArray *boxViews = [self allSubviewsInView:box];
        usbPort.hardwareId = (NSTextField *)[self viewWithIdentifier:@"hardwareId" inArray:boxViews];
        usbPort.status = (NSTextField *)[self viewWithIdentifier:@"status" inArray:boxViews];
        usbPort.progressIndicator = (NSProgressIndicator *)[self viewWithIdentifier:@"progressIndicator" inArray:boxViews];
        [usbPorts addObject:usbPort];
    }
    _usbPorts = usbPorts;
    [self loadLocations];
    
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
    if ([userDefaults objectForKey:@"usbVendorID"]) {
        _usbVendorIdTextField.stringValue = [userDefaults stringForKey:@"usbVendorID"];
    }
    if ([userDefaults objectForKey:@"usbProductID"]) {
        _usbProductIdTextField.stringValue = [userDefaults stringForKey:@"usbProductID"];
    }
    _userDefaultsLoaded = YES;
    
    _usbMonitor = [[FDUSBHIDMonitor alloc] init];
    _usbMonitor.vendor = [FDAppDelegate scanHexUInt16:_usbVendorIdTextField.stringValue];
    _usbMonitor.product = [FDAppDelegate scanHexUInt16:_usbProductIdTextField.stringValue];
    _usbMonitor.delegate = self;
    [_usbMonitor start];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
}

- (IBAction)showPreferences:(id)sender
{
    [_preferencesPanel setIsVisible:YES];
}

- (IBAction)resetToDefaults:(id)sender
{
    NSString *searchPath = [NSString stringWithFormat:@"%@/sandbox/denisbohm/firefly-ice-firmware", NSHomeDirectory()];
    NSURL *URL = [NSURL fileURLWithPath:searchPath isDirectory:YES];
    _searchPathControl.URL = URL;
    _firmwareNameTextField.stringValue = @"FireflyIce";
    _usbVendorIdTextField.stringValue = @"0x2333";
    _usbProductIdTextField.stringValue = @"0x0002";
    
    [self saveUserDefaults];
}

- (NSString *)getHexPath:(NSString *)name type:(NSString *)type searchPath:(NSString *)searchPath
{
// don't use these locations since they won't have the firmware metadata in the hex files
#if 0
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@.hex", searchPath, type, name, name];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:NO]) {
        return path;
    }
    
    path = [NSString stringWithFormat:@"%@/%@ THUMB Release/%@.hex", searchPath, name, name];
    if ([fileManager fileExistsAtPath:path isDirectory:NO]) {
        return path;
    }
#endif
    
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:searchPath error:nil];
    NSArray *files = [allFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"((self BEGINSWITH %@) AND (self ENDSWITH '.hex')) OR (self == %@)", [NSString stringWithFormat:@"%@-", name], [NSString stringWithFormat:@"%@.hex", name]]];
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

- (IBAction)clearLocations:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    for (FDUSBPort *usbPort in _usbPorts) {
        if (usbPort.usbHidDevice == nil) {
            usbPort.location = nil;
            [userDefaults removeObjectForKey:usbPort.identifier];
        }
    }
}

- (void)showOutOfLocationsAlert
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"All USB Port Locations Are Assigned.  Clear Locations?"];
    [alert setInformativeText:@"Do you want to clear the current USB port locations?"];
    [alert addButtonWithTitle:@"Clear Locations"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [self clearLocations:self];
    }
}

- (FDUSBPort *)usbPortForLocation:(NSObject *)location
{
    for (FDUSBPort *usbPort in _usbPorts) {
        if ([usbPort.location isEqual:location]) {
            return usbPort;
        }
    }
    return nil;
}

- (FDUSBPort *)usbPortWithNoLocation
{
    for (FDUSBPort *usbPort in _usbPorts) {
        if (usbPort.location == nil) {
            return usbPort;
        }
    }
    return nil;
}

- (FDUSBPort *)usbPortForDevice:(FDUSBHIDDevice *)usbHidDevice
{
    FDUSBPort *usbPort = [self usbPortForLocation:usbHidDevice.location];
    if (usbPort == nil) {
        usbPort = [self usbPortWithNoLocation];
        if (usbPort != nil) {
            usbPort.location = usbHidDevice.location;
            [self saveLocations];
        }
    }
    return usbPort;
}

- (void)usbHidMonitor:(FDUSBHIDMonitor *)monitor deviceAdded:(FDUSBHIDDevice *)usbHidDevice
{
    FDUSBPort *usbPort = [self usbPortForDevice:usbHidDevice];
    if (usbPort == nil) {
        [self showOutOfLocationsAlert];
        usbPort = [self usbPortForDevice:usbHidDevice];
        if (usbPort == nil) {
            return;
        }
    }
    usbPort.firmware = [self getFirmware];
    [usbPort start:usbHidDevice];
}

- (void)usbHidMonitor:(FDUSBHIDMonitor *)monitor deviceRemoved:(FDUSBHIDDevice *)usbHidDevice
{
    FDUSBPort *usbPort = [self usbPortForLocation:usbHidDevice.location];
    if (usbPort != nil) {
        [usbPort stop];
    }
}

- (void)enterStorageMode:(FDFireflyIce *)fireflyIce
{
    FDFireflyIceChannelBLE *channel = (FDFireflyIceChannelBLE *)fireflyIce.channels[@"BLE"];
    FDFireflyIceCoder *coder = [[FDFireflyIceCoder alloc] init];
    [coder sendSetPropertyMode:channel mode:FD_CONTROL_MODE_STORAGE];
}

@end
