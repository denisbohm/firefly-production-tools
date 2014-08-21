//
//  FDAppDelegate.m
//  FireflyTool
//
//  Created by Denis Bohm on 10/2/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"
#import "FDSerialWireDebugOperation.h"

#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialEngine.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>
#import <ARMSerialWireDebug/FDUSBDevice.h>
#import <ARMSerialWireDebug/FDUSBMonitor.h>

#import <FireflyProduction/FDRadioTest.h>

@interface FDAppDelegate () <FDUSBMonitorDelegate, FDLoggerConsumer, FDSerialWireDebugOperationDelegate>

@property (assign) IBOutlet NSTextField *jtagLabel;
@property (assign) IBOutlet NSTextField *pcbaLabel;
@property (assign) IBOutlet NSTextView *logView;
@property (assign) IBOutlet NSButton *testBatteryCheckBox;

@property (assign) IBOutlet NSTextField *bootAddressTextField;
@property (assign) IBOutlet NSTextField *bootNameTextField;
@property (assign) IBOutlet NSTextField *firmwareAddressTextField;
@property (assign) IBOutlet NSTextField *firmwareNameTextField;
@property (assign) IBOutlet NSTextField *metadataAddressTextField;
@property (assign) IBOutlet NSPathControl *searchPathControl;
@property (assign) IBOutlet NSTextField *ramSizeTextField;
@property (assign) IBOutlet NSComboBox *processorComboBox;

@property FDLogger *logger;
@property NSMutableDictionary *resources;
@property FDUSBMonitor *swdMonitor;
@property NSOperationQueue *operationQueue;
@property FDSerialWireDebugOperation *operation;

@property FDRadioTest *radioTest;

@end

@implementation FDAppDelegate

- (NSNumber *)parseNumber:(NSString *)text
{
    if ([text hasPrefix:@"0x"]) {
        NSScanner *scanner = [NSScanner scannerWithString:text];
        unsigned long long temp;
        [scanner scanHexLongLong:&temp];
        return [NSNumber numberWithLongLong:temp];
    }
    return [NSNumber numberWithLongLong:[text longLongValue]];
}

- (NSString *)formatNumber:(NSNumber *)number
{
    return [NSString stringWithFormat:@"0x%llx", [number unsignedLongLongValue]];
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
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:@"testBattery"]) {
        _testBatteryCheckBox.state = [userDefaults boolForKey:@"testBattery"];
        _bootAddressTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"bootAddress"]];
        _bootNameTextField.stringValue = [userDefaults stringForKey:@"bootName"];
        _firmwareAddressTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"firmwareAddress"]];
        _firmwareNameTextField.stringValue = [userDefaults stringForKey:@"firmwareName"];
        _metadataAddressTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"metadataAddress"]];
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
        _ramSizeTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"ramSize"]];
        [_processorComboBox selectItemWithObjectValue:[userDefaults objectForKey:@"processor"]];
    }
    
    _resources = [NSMutableDictionary dictionary];
    [self resourceChange:self];
    
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

- (IBAction)resourceChange:(id)sender
{
    _resources[@"testBattery"] = [NSNumber numberWithBool:_testBatteryCheckBox.state == NSOnState];
    _resources[@"bootAddress"] = [self parseNumber:_bootAddressTextField.stringValue];
    _resources[@"bootName"] = _bootNameTextField.stringValue;
    _resources[@"firmwareAddress"] = [self parseNumber:_firmwareAddressTextField.stringValue];
    _resources[@"firmwareName"] = _firmwareNameTextField.stringValue;
    _resources[@"metadataAddress"] = [self parseNumber:_metadataAddressTextField.stringValue];
    if ([_searchPathControl.URL isFileURL]) {
        _resources[@"searchPath"] = [_searchPathControl.URL path];
    } else {
        [_resources removeObjectForKey:@"searchPath"];
    }
    _resources[@"ramSize"] = [self parseNumber:_ramSizeTextField.stringValue];
    _resources[@"processor"] = _processorComboBox.stringValue;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [_resources enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
        [userDefaults setObject:value forKey:key];
    }];
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
}

- (void)serialWireDebugOperationDetected:(BOOL)detected
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pcbaDetected:detected];
    });
}

- (void)operationComplete
{
    _operation = nil;
    [_jtagLabel setDrawsBackground:NO];
    [_pcbaLabel setDrawsBackground:NO];
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceAdded:(FDUSBDevice *)usbDevice
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
    __weak FDAppDelegate *appDelegate = self;
    [_operation setCompletionBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate operationComplete];
        });
    }];
    [_operationQueue addOperation:_operation];
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceRemoved:(FDUSBDevice *)usbDevice
{
}


@end
