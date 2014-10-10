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

@property (assign) IBOutlet NSTextField *usbVendorIdTextField;
@property (assign) IBOutlet NSTextField *usbProductIdTextField;

@property NSArray *usbPorts;

@property FDUSBHIDMonitor *usbMonitor;

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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
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
    _usbMonitor = [[FDUSBHIDMonitor alloc] init];
    if ([userDefaults objectForKey:@"usbVendorID"]) {
        _usbVendorIdTextField.stringValue = [userDefaults stringForKey:@"usbVendorID"];
        _usbMonitor.vendor = [FDAppDelegate scanHexUInt16:_usbVendorIdTextField.stringValue];
    } else {
        _usbMonitor.vendor = 0x2333;
    }
    if ([userDefaults objectForKey:@"usbProductID"]) {
        _usbProductIdTextField.stringValue = [userDefaults stringForKey:@"usbProductID"];
        _usbMonitor.product = [FDAppDelegate scanHexUInt16:_usbProductIdTextField.stringValue];
    } else {
        _usbMonitor.product = 0x0002;
    }
    _usbMonitor.delegate = self;
    [_usbMonitor start];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
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
