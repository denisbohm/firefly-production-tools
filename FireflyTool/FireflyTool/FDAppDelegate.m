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

@property FDLogger *logger;
@property FDUSBMonitor *swdMonitor;
@property NSOperationQueue *operationQueue;
@property FDSerialWireDebugOperation *operation;

@property FDRadioTest *radioTest;

@end

@implementation FDAppDelegate

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
    
    /*
    _radioTest = [[FDRadioTest alloc] init];
    _radioTest.logger = self.logger;
    [_radioTest start];
    uint8_t bytes[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *writeData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    [_radioTest startTest:@"hwid53d6b75003678324" delegate:nil data:writeData];
     */
    
    [_swdMonitor start];
}

- (void)clearLog
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
    
    [self clearLog];
    [_jtagLabel setDrawsBackground:YES];
    [_pcbaLabel setDrawsBackground:NO];

    _operation = [[FDSerialWireDebugOperation alloc] init];
    _operation.logger = _logger;
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
