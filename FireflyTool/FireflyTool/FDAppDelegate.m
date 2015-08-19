//
//  FDAppDelegate.m
//  FireflyTool
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"

#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialEngine.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>
#import <ARMSerialWireDebug/FDUSBDevice.h>
#import <ARMSerialWireDebug/FDUSBMonitor.h>

#import <FireflyProduction/FDRadioTest.h>
#import <FireflyProduction/FDSerialWireDebugOperation.h>
#import <FireflyProduction/FDTargetOptionsView.h>

#import "FDFireflyIceMint.h"
#import "FDFireflyIceRadioTest.h"
#import "FDFireflyIceTest.h"
#import "FDFireflyIceUsbTest.h"

@interface FDAppDelegate () <FDUSBMonitorDelegate, FDLoggerConsumer, FDSerialWireDebugOperationDelegate, FDTargetOptionsViewDelegate>

@property (assign) IBOutlet NSTextField *jtagLabel;
@property (assign) IBOutlet NSTextField *pcbaLabel;
@property (assign) IBOutlet NSButton *runButton;
@property (assign) IBOutlet NSButton *autoCheckBox;
@property (assign) IBOutlet NSTextField *operationLabel;
@property (assign) IBOutlet NSTextView *logView;

@property (assign) IBOutlet NSButton *programCheckBox;
@property (assign) IBOutlet NSButton *testCheckBox;
@property (assign) IBOutlet NSButton *testBatteryCheckBox;
@property (assign) IBOutlet NSButton *testBLECheckBox;
@property (assign) IBOutlet NSButton *testUSBCheckBox;

@property (assign) IBOutlet FDTargetOptionsView *targetOptionsView;

@property FDLogger *logger;
@property NSMutableDictionary *resources;
@property FDUSBMonitor *swdMonitor;
@property NSOperationQueue *operationQueue;
@property FDSerialWireDebugOperation *operation;

@property FDRadioTest *radioTest;

@end

@implementation FDAppDelegate

- (IBAction)resourceChange:(id)sender
{
    [_resources setValuesForKeysWithDictionary:self.targetOptionsView.resources];
    
    _resources[@"program"] = [NSNumber numberWithBool:_programCheckBox.state == NSOnState];
    
    _resources[@"test"] = [NSNumber numberWithBool:_testCheckBox.state == NSOnState];
    _resources[@"testBattery"] = [NSNumber numberWithBool:_testBatteryCheckBox.state == NSOnState];
    _resources[@"testBLE"] = [NSNumber numberWithBool:_testBLECheckBox.state == NSOnState];
    _resources[@"testUSB"] = [NSNumber numberWithBool:_testUSBCheckBox.state == NSOnState];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [_resources enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
        [userDefaults setObject:value forKey:key];
    }];
}

- (void)targetOptionsViewChange:(FDTargetOptionsView *)view
{
    [self resourceChange:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    _logger = [[FDLogger alloc] init];
    _logger.consumer = self;
    
    _operationQueue = [[NSOperationQueue alloc] init];
    
    _swdMonitor = [[FDUSBMonitor alloc] init];
    _swdMonitor.logger.consumer = self;
    _swdMonitor.vendor = 0x15ba;
    _swdMonitor.product = 0x002a;
    _swdMonitor.delegate = self;

    _resources = [NSMutableDictionary dictionary];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:@"program"]) {
        _programCheckBox.state = [userDefaults boolForKey:@"program"];
        _testCheckBox.state = [userDefaults boolForKey:@"test"];
        _testBatteryCheckBox.state = [userDefaults boolForKey:@"testBattery"];
        _testBLECheckBox.state = [userDefaults boolForKey:@"testBLE"];
        _testUSBCheckBox.state = [userDefaults boolForKey:@"testUSB"];
    }
    [self resourceChange:self];
    
    _autoCheckBox.state = [userDefaults boolForKey:@"auto"] ? NSOnState : NSOffState;
    
    _targetOptionsView.delegate = self;
    
#if 0
    _radioTest = [[FDRadioTest alloc] init];
    _radioTest.logger = self.logger;
    [_radioTest start];
    uint8_t bytes[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *writeData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    [_radioTest startTest:@"hwid0123" delegate:nil data:writeData];
#else
    [_swdMonitor start];
#endif
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) theApplication
{
    return YES;
}

- (IBAction)showPreferences:(id)sender
{
    [_preferencesPanel setIsVisible:YES];
}

- (IBAction)clearLog:(id)sender
{
    NSTextStorage* textStorage = _logView.textStorage;
    [textStorage deleteCharactersInRange:NSMakeRange(0, textStorage.length)];
}

- (void)logFile:(char *)file line:(NSUInteger)line class:(NSString *)class method:(NSString *)method message:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self log:message];
    });
}

- (void)log:(NSString *)message
{
    BOOL scrollAfter = NSMaxY(_logView.visibleRect) >= NSMaxY(_logView.bounds);
    NSTextStorage* textStorage = _logView.textStorage;
    if (textStorage.length > 0) {
        [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    }
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:message]];
    if (scrollAfter) {
        [_logView scrollRangeToVisible:NSMakeRange(textStorage.length, 0)];
    }
}

- (void)pcbaDetected:(BOOL)detected
{
    [_pcbaLabel setDrawsBackground:detected];
    _runButton.enabled = detected;
}

- (void)serialWireDebugOperationDetected:(BOOL)detected
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pcbaDetected:detected];
    });
}

- (NSArray *)serialWireDebugOperationTasks
{
    NSMutableArray *tasks = [NSMutableArray array];
    if ([_resources[@"test"] boolValue]) {
        [tasks addObject:[[FDFireflyIceTest alloc] init]];
        if ([_resources[@"testBLE"] boolValue]) {
            [tasks addObject:[[FDFireflyIceRadioTest alloc] init]];
        }
        if ([_resources[@"testUSB"] boolValue]) {
            [tasks addObject:[[FDFireflyIceUsbTest alloc] init]];
        }
    }
    if ([_resources[@"program"] boolValue]) {
        [tasks addObject:[[FDFireflyIceMint alloc] init]];
    }
    return tasks;
}

- (void)serialWireDebugOperationStarting
{
    _operationLabel.hidden = YES;
    _runButton.enabled = NO;
}

- (void)operationComplete:(BOOL)success
{
    _operationLabel.stringValue = success ? @"pass" : @"FAIL";
    _operationLabel.backgroundColor = success ? [NSColor blueColor] : [NSColor redColor];
    _operationLabel.hidden = NO;
    _runButton.enabled = YES;
}

- (void)serialWireDebugOperationComplete:(BOOL)success
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self operationComplete:success];
    });
}

- (void)startTest:(FDUSBDevice *)usbDevice
{
    if (_operation != nil) {
        return;
    }
    
    [self clearLog:self];
    [_jtagLabel setDrawsBackground:YES];
    [_pcbaLabel setDrawsBackground:NO];
    
    _operation = [[FDSerialWireDebugOperation alloc] init];
    _operation.logger = _logger;
    _operation.resources = _resources;
    _operation.usbDevice = usbDevice;
    _operation.delegate = self;
    _operation.run = _autoCheckBox.state == NSOnState;
    __weak FDAppDelegate *appDelegate = self;
    [_operation setCompletionBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate operationComplete];
        });
    }];
    [_operationQueue addOperation:_operation];
}

- (IBAction)autoChanged:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:_autoCheckBox.state == NSOnState forKey:@"auto"];
    
    _operation.autoRun = _autoCheckBox.state == NSOnState;
    if (_operation.autoRun && _operation.detected) {
        _operation.run = YES;
    }
}

- (void)operationComplete
{
    _operation = nil;
    [_jtagLabel setDrawsBackground:NO];
    [_pcbaLabel setDrawsBackground:NO];
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceAdded:(FDUSBDevice *)usbDevice
{
    [self startTest:usbDevice];
}

- (IBAction)runTest:(id)sender
{
    _operation.run = YES;
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceRemoved:(FDUSBDevice *)usbDevice
{
}

@end
