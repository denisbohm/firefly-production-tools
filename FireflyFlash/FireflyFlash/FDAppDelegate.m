//
//  FDAppDelegate.m
//  FireflyFlash
//
//  Created by Denis Bohm on 4/30/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"

#import <FireflyProduction/FDExecutable.h>
#import <FireflyProduction/FDFireflyFlash.h>
#import <FireflyProduction/FDGdbServer.h>
#import <FireflyProduction/FDGdbServerSwd.h>

#import <FireflyDevice/FDUSBHIDMonitor.h>

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialEngine.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>
#import <ARMSerialWireDebug/FDUSBDevice.h>
#import <ARMSerialWireDebug/FDUSBMonitor.h>

@interface FDUSBTableViewDataSource : NSObject  <NSTableViewDataSource>

@property NSMutableArray *devices;

@end

@implementation FDUSBTableViewDataSource

- (id)init
{
    if (self = [super init]) {
        _devices = [NSMutableArray array];
    }
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _devices.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return [[_devices objectAtIndex:rowIndex] description];
}

@end

@interface FDAppDelegate () <FDUSBMonitorDelegate, NSTableViewDataSource, FDLoggerConsumer>

@property (assign) IBOutlet NSTableView *swdTableView;
@property FDUSBMonitor *swdMonitor;
@property FDUSBTableViewDataSource *swdTableViewDataSource;
@property (assign) IBOutlet NSTextView *swdTextView;
@property (assign) IBOutlet NSPathControl *swdPathControl;
@property (assign) IBOutlet NSImageView *swdJtagImageView;
@property (assign) IBOutlet NSImageView *swdGdbImageView;
@property (assign) IBOutlet NSImageView *swdRunningImageView;
@property (assign) IBOutlet NSButton *connectButton;
@property (assign) IBOutlet NSButton *disconnectButton;
@property (assign) IBOutlet NSButton *programButton;
@property (assign) IBOutlet NSButton *resetButton;

@property FDGdbServer *gdbServer;
@property FDGdbServerSwd *gdbServerSwd;

@property FDLogger *logger;

@end

@implementation FDAppDelegate

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSString *firmwarePath = _swdPathControl.URL.path;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:firmwarePath forKey:@"firmwarePath"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _logger = [[FDLogger alloc] init];
    _logger.consumer = self;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *firmwarePath = [userDefaults stringForKey:@"firmwarePath"];
    if (firmwarePath) {
        _swdPathControl.URL = [[NSURL alloc] initFileURLWithPath:firmwarePath];
    }
    
    _swdMonitor = [[FDUSBMonitor alloc] init];
    _swdMonitor.logger.consumer = self;
    _swdMonitor.vendor = 0x15ba;
    _swdMonitor.product = 0x002a;
    _swdMonitor.delegate = self;
    _swdTableViewDataSource = [[FDUSBTableViewDataSource alloc] init];
    _swdTableView.dataSource = _swdTableViewDataSource;
    
    [_swdMonitor start];
    
    _gdbServer = [[FDGdbServer alloc] init];
    _gdbServer.logger.consumer = self;
    _gdbServerSwd = [[FDGdbServerSwd alloc] init];
    _gdbServerSwd.logger.consumer = self;
    _gdbServer.delegate = _gdbServerSwd;
    _gdbServerSwd.gdbServer = _gdbServer;
    [_gdbServer addObserver:self forKeyPath:@"connected" options:NSKeyValueObservingOptionNew context:nil];
    [_gdbServerSwd addObserver:self forKeyPath:@"halted" options:NSKeyValueObservingOptionNew context:nil];
    [_gdbServer start];
}

- (void)swdDeviceAdded:(FDUSBDevice *)device
{
    [_swdTableViewDataSource.devices addObject:device];
    [_swdTableView reloadData];
    
    if (!_gdbServerSwd.serialWireDebug) {
        [self performSelectorOnMainThread:@selector(swdSelectAndConnect:) withObject:device waitUntilDone:NO];
    }
}

- (void)swdSelectAndConnect:(FDUSBDevice *)device
{
    [_swdTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [self swdConnect:nil];
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceAdded:(FDUSBDevice *)device
{
    [self performSelectorOnMainThread:@selector(swdDeviceAdded:) withObject:device waitUntilDone:NO];
}

- (void)swdDeviceRemoved:(FDUSBDevice *)device
{
    [_swdTableViewDataSource.devices removeObject:device];
    [_swdTableView reloadData];
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceRemoved:(FDUSBDevice *)device
{
    [self performSelectorOnMainThread:@selector(swdDeviceRemoved:) withObject:device waitUntilDone:NO];
}

- (void)logFile:(char *)file line:(NSUInteger)line class:(NSString *)class method:(NSString *)method message:(NSString *)message
{
    BOOL scrollAfter = NSMaxY(_swdTextView.visibleRect) >= NSMaxY(_swdTextView.bounds);
    NSTextStorage* storage = _swdTextView.textStorage;
    if (storage.length > 0) {
        [storage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    }
    [storage appendAttributedString:[[NSAttributedString alloc] initWithString:message]];
    if (scrollAfter) {
        [_swdTextView scrollRangeToVisible:NSMakeRange(storage.length, 0)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([@"connected" isEqualToString:keyPath]) {
        [_swdGdbImageView setAlphaValue:_gdbServer.connected ? 1.0 : 0.25];
    } else
    if ([@"halted" isEqualToString:keyPath]) {
        [_swdRunningImageView setAlphaValue:!_gdbServerSwd.halted ? 1.0 : 0.25];
    }
}

- (FDUSBDevice *)getSelectedSwdDevice
{
    NSInteger row = _swdTableView.selectedRow;
    if (row < 0) {
        return nil;
    }
    return [_swdTableViewDataSource.devices objectAtIndex:row];
}

- (IBAction)swdConnect:(id)sender
{
    FDUSBDevice *usbDevice = [self getSelectedSwdDevice];
    [usbDevice open];
    FDSerialEngine *serialEngine = [[FDSerialEngine alloc] init];
    serialEngine.timeout = 0; // !!! need to move swd to a separate thread and enable timeout -denis
    serialEngine.usbDevice = usbDevice;
    FDSerialWireDebug *serialWireDebug = [[FDSerialWireDebug alloc] init];
    serialWireDebug.serialEngine = serialEngine;
    [serialWireDebug initialize];
    [serialWireDebug setGpioIndicator:true];
    [serialWireDebug setGpioReset:true];
    [serialEngine write];
    [NSThread sleepForTimeInterval:0.001];
    [serialWireDebug setGpioReset:false];
    [serialEngine write];
    [NSThread sleepForTimeInterval:0.100];
    
    FDCortexM *cortexM = [[FDCortexM alloc] init];
    cortexM.logger.consumer = self;
    cortexM.serialWireDebug = serialWireDebug;
    [cortexM identify];
    
    [serialWireDebug halt];
    NSLog(@"CPU Halted %@", [serialWireDebug isHalted] ? @"YES" : @"NO");
    
    _gdbServerSwd.serialWireDebug = serialWireDebug;
    [_connectButton setEnabled:NO];
    [_programButton setEnabled:YES];
    [_resetButton setEnabled:YES];
    [_disconnectButton setEnabled:YES];
    [_swdJtagImageView setAlphaValue:1.0];
}

- (IBAction)swdDisconnect:(id)sender
{
    _gdbServerSwd.serialWireDebug = nil;
    [_connectButton setEnabled:YES];
    [_programButton setEnabled:NO];
    [_resetButton setEnabled:NO];
    [_disconnectButton setEnabled:NO];
    [_swdJtagImageView setAlphaValue:0.25];
}

- (void)verify:(uint32_t)address data:(NSData *)data
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    NSData *verify = [serialWireDebug readMemory:address length:(uint32_t)data.length];
    if (![data isEqualToData:verify]) {
        uint8_t *dataBytes = (uint8_t *)data.bytes;
        uint8_t *verifyBytes = (uint8_t *)verify.bytes;
        NSUInteger i;
        for (i = 0; i < data.length; ++i) {
            if (dataBytes[i] != verifyBytes[i]) {
                break;
            }
        }
        @throw [NSException exceptionWithName:@"verify issue"reason:[NSString stringWithFormat:@"verify issue at %lu %02x != %02x", (unsigned long)i, dataBytes[i], verifyBytes[i]] userInfo:nil];
    }
}

- (IBAction)swdProgram:(id)sender
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    
    NSString *firmwarePath = _swdPathControl.URL.path;
    if (!firmwarePath) {
        FDLog(@"no firmware file selected");
        return;
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:firmwarePath forKey:@"firmwarePath"];
    FDLog(@"reading %@", firmwarePath);
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:firmwarePath];
    NSArray *sections = [executable combineSectionsType:FDExecutableSectionTypeProgram address:0 length:0x40000 pageSize:2048];
    executable.sections = sections;
    
    FDLog(@"Loading FireflyFlash into RAM...");
    FDFireflyFlash *flash = [FDFireflyFlash fireflyFlash:@"NRF51"]; // !!! need to pick the correct processor here -denis
    flash.logger = self.logger;
    [flash initialize:serialWireDebug];
    
    FDLog(@"starting mass erase");
    [flash massErase];

    FDLog(@"loading firmware into flash...");
    FDExecutableSection *section = executable.sections[0];
    uint32_t address = 0x00000000;
    [flash writePages:address data:section.data erase:YES];
    [self verify:address data:section.data];

    FDLog(@"resetting");
    [serialWireDebug reset];
    [serialWireDebug run];
    FDLog(@"program loaded");
}

- (IBAction)swdReset:(id)sender
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    
    [serialWireDebug halt];
    [serialWireDebug reset];
    [serialWireDebug run];
}

@end