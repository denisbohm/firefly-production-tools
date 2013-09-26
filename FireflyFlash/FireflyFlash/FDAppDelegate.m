//
//  FDAppDelegate.m
//  FireflyFlash
//
//  Created by Denis Bohm on 4/30/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"

#import <FireflyDeviceFramework/FDBinary.h>
#import <FireflyDeviceFramework//FDCrypto.h>
#import <FireflyDeviceFramework/FDFireflyIce.h>
#import <FireflyDeviceFramework/FDFireflyIceChannelBLE.h>

#import <FireflyProduction/FDExecutable.h>
#import <FireflyProduction/FDFireflyFlash.h>
#import <FireflyProduction/FDGdbServer.h>
#import <FireflyProduction/FDGdbServerSwd.h>
#import <FireflyProduction/FDRadioTest.h>
#import <FireflyProduction/FDUSBHIDMonitor.h>

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDEFM32.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialEngine.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>
#import <ARMSerialWireDebug/FDUSBDevice.h>
#import <ARMSerialWireDebug/FDUSBMonitor.h>

#if TARGET_OS_IPHONE
#import <CoreBluetooth/CoreBluetooth.h>
#else
#import <IOBluetooth/IOBluetooth.h>
#endif

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

@interface FDAppDelegate () <CBCentralManagerDelegate, FDUSBMonitorDelegate, FDUSBHIDMonitorDelegate, FDUSBHIDDeviceDelegate, FDFireflyIceObserver, NSTableViewDataSource, FDLoggerConsumer, FDRadioTestDelegate>

@property (assign) IBOutlet NSTableView *bluetoothTableView;
@property CBCentralManager *centralManager;
@property NSMutableArray *fireflyDevices;

@property (assign) IBOutlet NSTableView *usbTableView;
@property FDUSBHIDMonitor *usbMonitor;
@property FDUSBTableViewDataSource *usbTableViewDataSource;

@property (assign) IBOutlet NSTableView *swdTableView;
@property FDUSBMonitor *swdMonitor;
@property FDUSBTableViewDataSource *swdTableViewDataSource;
@property (assign) IBOutlet NSTextView *swdTextView;
@property (assign) IBOutlet NSPathControl *swdPathControl;
@property (assign) IBOutlet NSImageView *swdJtagImageView;
@property (assign) IBOutlet NSImageView *swdGdbImageView;
@property (assign) IBOutlet NSImageView *swdRunningImageView;
@property (assign) IBOutlet NSButton *programButton;
@property (assign) IBOutlet NSButton *resetButton;
@property (assign) IBOutlet NSButton *testButton;
@property (assign) IBOutlet NSButton *mintButton;

@property (assign) IBOutlet NSSlider *axSlider;
@property (assign) IBOutlet NSSlider *aySlider;
@property (assign) IBOutlet NSSlider *azSlider;

@property (assign) IBOutlet NSSlider *mxSlider;
@property (assign) IBOutlet NSSlider *mySlider;
@property (assign) IBOutlet NSSlider *mzSlider;

@property FDGdbServer *gdbServer;
@property FDGdbServerSwd *gdbServerSwd;

@property FDLogger *logger;

@property double radioTestSpeed;
@property double radioTestStrength;
@property FDRadioTest *radioTest;
@property FDRadioTestResult *radioTestResult;

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
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _fireflyDevices = [NSMutableArray array];
    _bluetoothTableView.dataSource = self;
    
    _usbMonitor = [[FDUSBHIDMonitor alloc] init];
    _usbMonitor.vendor = 0x2544;
    _usbMonitor.product = 0x0001;
    _usbMonitor.delegate = self;
    _usbTableViewDataSource = [[FDUSBTableViewDataSource alloc] init];
    _usbTableView.dataSource = _usbTableViewDataSource;
    
    _swdMonitor = [[FDUSBMonitor alloc] init];
    _swdMonitor.logger.consumer = self;
    _swdMonitor.vendor = 0x15ba;
    _swdMonitor.product = 0x002a;
    _swdMonitor.delegate = self;
    _swdTableViewDataSource = [[FDUSBTableViewDataSource alloc] init];
    _swdTableView.dataSource = _swdTableViewDataSource;
    
    [_usbMonitor start];
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
    
    _radioTestSpeed = 100;
    _radioTestStrength = -80;
    _radioTest = [[FDRadioTest alloc] init];
    [_radioTest start];
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

#define EnergyMicro_DebugPort_IdentifcationCode 0x2ba01477f
#define Nuvoton_DebugPort_IdentifcationCode 0x0bb11477

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
    [_programButton setEnabled:YES];
    [_resetButton setEnabled:YES];
    [_testButton setEnabled:YES];
    [_mintButton setEnabled:YES];
    [_swdJtagImageView setAlphaValue:1.0];
}

- (IBAction)swdDisconnect:(id)sender
{
    _gdbServerSwd.serialWireDebug = nil;
    [_programButton setEnabled:NO];
    [_resetButton setEnabled:NO];
    [_testButton setEnabled:NO];
    [_mintButton setEnabled:NO];
    [_swdJtagImageView setAlphaValue:0.25];
}

/*
 - (IBAction)swdTest:(id)sender
 FDLog(@"write memory");
 uint32_t address = 0x20000000;
 [serialWireDebug writeMemory:address value:0x01234567];
 [serialWireDebug checkDebugPortStatus];
 [serialWireDebug writeMemory:address + 4 value:0x76543210];
 FDLog(@"read memory");
 uint32_t m0 = [serialWireDebug readMemory:address];
 uint32_t m1 = [serialWireDebug readMemory:address+4];
 FDLog(@"m0 = %08x, m1 = %08x", m0, m1);
 
 FDLog(@"write register");
 [serialWireDebug writeRegister:0 value:0x01234567];
 [serialWireDebug writeRegister:1 value:0x76543210];
 FDLog(@"read register");
 uint32_t r0 = [serialWireDebug readRegister:0];
 uint32_t r1 = [serialWireDebug readRegister:1];
 FDLog(@"r0 = %08x, r1 = %08x", r0, r1);
 
 FDLog(@"bluk memory read/write");
 address = 0x20000000;
 uint32_t length = 1024;
 NSMutableData *data = [NSMutableData dataWithCapacity:length];
 for (NSUInteger i = 0; i < length; ++i) {
 uint8_t byte = random();
 [data appendBytes:&byte length:1];
 }
 NSDate *before = [NSDate date];
 [serialWireDebug writeMemory:address data:data];
 NSDate *between = [NSDate date];
 NSData *output = [serialWireDebug readMemory:address length:(UInt32)data.length];
 NSDate *after = [NSDate date];
 if ([data isEqualToData:output]) {
 double writeBps = data.length / [between timeIntervalSinceDate:before];
 double readBps = output.length / [after timeIntervalSinceDate:between];
 FDLog(@"pass write = %0.1f Bps, read = %0.1f Bps", writeBps, readBps);
 } else {
 FDLog(@"fail");
 FDLog(@"data = %@", data);
 FDLog(@"output = %@", output);
 }
 
 FDLog(@"erase & program");
 address = 0x00000000;
 [serialWireDebug erase:address];
 before = [NSDate date];
 [serialWireDebug program:address data:data];
 after = [NSDate date];
 double programBps = data.length / [after timeIntervalSinceDate:before];
 NSData *readData = [serialWireDebug readMemory:address length:(UInt32)data.length];
 if ([data isEqualToData:readData]) {
 FDLog(@"pass program = %0.1f Bps", programBps);
 } else {
 FDLog(@"fail");
 FDLog(@"data = %@", data);
 FDLog(@"output = %@", readData);
 }
 }
 */

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
    FDLog(@"mass erase");
    [serialWireDebug massErase];
    for (FDExecutableSection *section in executable.sections) {
        switch (section.type) {
            case FDExecutableSectionTypeProgram: {
                FDLog(@"loading flash");
                [serialWireDebug writeMemory:section.address data:section.data];
                NSData *verify = [serialWireDebug readMemory:section.address length:(uint32_t)section.data.length];
                if ([section.data isEqualToData:verify]) {
                    FDLog(@"flash verified");
                } else {
                    FDLog(@"flash program failure");
                }
            } break;
            case FDExecutableSectionTypeData:
                FDLog(@"loading RAM");
                [serialWireDebug writeMemory:section.address data:section.data];
                break;
        }
    }
    FDLog(@"resetting");
    [serialWireDebug reset];
    [serialWireDebug run];
    FDLog(@"program loaded");
    
    /*
     FDExecutableFunction *function = executable.functions[@"test_led"];
     FDCortexM *cortexM = [[FDCortexM alloc] init];
     cortexM.serialWireDebug = serialWireDebug;
     [cortexM run:function.address timeout:1.0];
     */
}

- (FDExecutable *)load:(NSString *)name type:(NSString *)type
{
    NSString *path = [NSString stringWithFormat:@"/Users/denis/sandbox/denisbohm/firefly-ice-firmware/%@/%@/%@.elf", type, name, name];
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:path];
    NSArray *sections = [executable combineSectionsType:FDExecutableSectionTypeProgram
                                                address:0
                                                 length:0x40000
                                               pageSize:2048];
    executable.sections = sections;
    return executable;
}

static uint8_t secretKey[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};

- (NSMutableData *)getMetadata:(NSData *)data
{
    NSData *hash = [FDCrypto sha1:data];
    FDBinary *binary = [[FDBinary alloc] init];
    [binary putUInt32:0]; // flags
    [binary putUInt32:(uint32_t)data.length];
    [binary putData:hash];
    [binary putData:hash];
    NSMutableData *iv = [NSMutableData data];
    iv.length = 16;
    [binary putData:iv];
    return [NSMutableData dataWithData:[binary dataValue]];
}

#define FD_UPDATE_BOOT_ADDRESS 0x0000
#define FD_UPDATE_CRYPTO_ADDRESS 0x7000
#define FD_UPDATE_METADATA_ADDRESS 0x7800
#define FD_UPDATE_FIRMWARE_ADDRESS 0x8000

#define FD_UPDATE_DATA_BASE_ADDRESS 0x00000000

- (void)verify:(uint32_t)address data:(NSData *)data
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    NSData *verify = [serialWireDebug readMemory:address length:(uint32_t)data.length];
    if (![data isEqualToData:verify]) {
        @throw [NSException exceptionWithName:@"verify issue"reason:@"verify issue" userInfo:nil];
    }
}

- (IBAction)mint:(id)sender
{
    FDLog(@"Mint Starting");
    
    FDLog(@"Loading FireflyFlash into RAM...");
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    FDFireflyFlash *flash = [[FDFireflyFlash alloc] init];
    flash.logger.consumer = self;
    [flash initialize:serialWireDebug];

    FDLog(@"loading FireflyBoot info flash...");
    FDExecutable *fireflyBoot = [self load:@"FireflyBoot" type:@"THUMB Flash Release"];
    FDExecutableSection *fireflyBootSection = fireflyBoot.sections[0];
    [flash writePages:FD_UPDATE_BOOT_ADDRESS data:fireflyBootSection.data erase:YES];
    [self verify:FD_UPDATE_BOOT_ADDRESS data:fireflyBootSection.data];
    
    FDLog(@"loading firmware update crypto key into flash...");
    NSMutableData *cryptoKey = [NSMutableData dataWithBytes:secretKey length:sizeof(secretKey)];
    cryptoKey.length = flash.pageSize;
    [flash writePages:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey erase:YES];
    [self verify:FD_UPDATE_CRYPTO_ADDRESS data:cryptoKey];

    FDLog(@"loading firmware metadata into flash");
    FDExecutable *fireflyIce = [self load:@"FireflyIce" type:@"THUMB Flash Release"];
    FDExecutableSection *fireflyIceSection = fireflyIce.sections[0];
    NSMutableData *metadata = [self getMetadata:fireflyIceSection.data];
    metadata.length = flash.pageSize;
    [flash writePages:FD_UPDATE_METADATA_ADDRESS data:metadata erase:YES];
    [self verify:FD_UPDATE_METADATA_ADDRESS data:metadata];

    FDLog(@"loading firmware into flash...");
    [flash writePages:FD_UPDATE_FIRMWARE_ADDRESS data:fireflyIceSection.data erase:YES];
    [self verify:FD_UPDATE_FIRMWARE_ADDRESS data:fireflyIceSection.data];
    
    FDLog(@"Reset & Run...");
    [serialWireDebug reset];
    [serialWireDebug run];
    
    FDLog(@"Mint Finished");
}

- (IBAction)swdReset:(id)sender
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    
    [serialWireDebug halt];
    [serialWireDebug reset];
    [serialWireDebug run];
}

- (void)loadExecutableIntoRam:(FDExecutable *)executable
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;

    NSMutableData *data = [NSMutableData data];
    for (int i = 0; i < 0x4000; ++i) {
        uint8_t byte = 0;
        [data appendBytes:&byte length:1];
    }
    [serialWireDebug writeMemory:0x20000000 data:data];
    @try {
        for (FDExecutableSection *section in executable.sections) {
            switch (section.type) {
                case FDExecutableSectionTypeData:
                case FDExecutableSectionTypeProgram:
                    [serialWireDebug writeMemory:section.address data:section.data];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"load exception: %@", e);
    }
}

- (FDCortexM *)setupCortexRanges:(FDExecutable *)executable stackLength:(NSUInteger)stackLength heapLength:(NSUInteger)heapLength
{
    uint32_t ramStart = 0x20000000;
    uint32_t ramLength = 0x2000;
    
    uint32_t programAddressEnd = ramStart;
    for (FDExecutableSection *section in executable.sections) {
        switch (section.type) {
            case FDExecutableSectionTypeData:
            case FDExecutableSectionTypeProgram: {
                uint32_t sectionAddressEnd = (uint32_t)(section.address + section.data.length);
                if (sectionAddressEnd > programAddressEnd) {
                    programAddressEnd = sectionAddressEnd;
                }
            } break;
        }
    }
    uint32_t programLength = programAddressEnd - ramStart;
    
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;

    FDCortexM *cortexM = [[FDCortexM alloc] init];
    cortexM.logger.consumer = self;
    cortexM.serialWireDebug = serialWireDebug;

    cortexM.programRange.location = ramStart;
    cortexM.programRange.length = programLength;
    cortexM.stackRange.location = ramStart + ramLength - stackLength;
    cortexM.stackRange.length = stackLength;
    cortexM.heapRange.location = cortexM.stackRange.location - heapLength;
    cortexM.heapRange.length = heapLength;
    
    if (cortexM.heapRange.location < (cortexM.programRange.location + cortexM.programRange.length)) {
        @throw [NSException exceptionWithName:@"CORTEXOUTOFRAM" reason:@"Cortex out of RAM" userInfo:nil];
    }
    
    return cortexM;
}

- (FDCortexM *)loadFirmwareIntoRam:(FDExecutable *)executable
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    
    FDFireflyFlash *flash = [[FDFireflyFlash alloc] init];
    [flash initialize:serialWireDebug];
    [flash disableWatchdogByErasingIfNeeded];
    
    [self loadExecutableIntoRam:executable];
    FDCortexM *cortexM = [self setupCortexRanges:executable stackLength:256 heapLength:128];
    FDExecutableFunction *halt = executable.functions[@"halt"];
    cortexM.breakLocation = halt.address;
    @try {
        FDExecutableFunction *initialize = executable.functions[@"initialize"];
        [cortexM run:initialize.address timeout:5.0];
    } @catch (NSException *e) {
        NSLog(@"unexpected exception during initialization: %@", e);
    }
    return cortexM;
}

- (FDExecutable *)loadExecutable:(NSString *)type name:(NSString *)name
{
    NSString *path = [NSString stringWithFormat:@"/Users/denis/sandbox/denisbohm/mouth_piece/bin/%@.elf", name];
    //    NSString *path = [[NSBundle bundleForClass: [self class]] pathForResource:name ofType:@"elf"];
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:path];
    return executable;
}

- (FDExecutable *)combineExecutableInRAM:(FDExecutable *)executable
{
    executable.sections = [executable combineAllSectionsType:FDExecutableSectionTypeProgram address:0x20000000 length:0x2000 pageSize:4];
    return executable;
}

- (void)radioTest:(FDRadioTest *)radioTest discovered:(NSString *)name
{
    NSLog(@"discovered radio %@", name);
}

- (void)radioTest:(FDRadioTest *)radioTest complete:(NSString *)name result:(FDRadioTestResult *)result
{
    NSLog(@"completed radio test for %@: %@ %0.2f %0.3f", name, result.pass ? @"pass" : @"fail", result.rssi, result.duration);
    
    if (!result.pass) {
        NSLog(@"radio test failed");
    }
}

- (void)addNote:(NSMutableString *)notes message:(NSString *)message
{
    FDLog(message);
    if (notes.length > 0) {
        [notes appendString:@"; "];
    }
    [notes appendString:message];
}

- (BOOL)testRadio:(FDCortexM *)cortexM notes:(NSMutableString *)notes
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    
    FDExecutable *firmware = [self combineExecutableInRAM:[self loadExecutable:@"RAM Debug" name:@"TestRadio"]];

    NSData *hardwareId = [serialWireDebug readMemory:EFM32_UNIQUE_0 length:8];
    NSMutableString *name = [NSMutableString stringWithString:@"hwid"];
    {
        uint8_t *bytes = (uint8_t *)hardwareId.bytes;
        for (NSUInteger i = 0; i < hardwareId.length; ++i) {
            uint8_t byte = bytes[i];
            [name appendFormat:@"%02x", byte];
        }
    }
    
    NSLog(@"starting radio test for %@", name);
    _radioTestResult = nil;
    uint8_t bytes[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *writeData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    [_radioTest startTest:name delegate:self data:writeData];
    FDExecutableFunction *radio_test = firmware.functions[@"radio_test"];
    uint32_t address = cortexM.heapRange.location;
    uint32_t result = [cortexM run:radio_test.address r0:address r1:sizeof(bytes) timeout:15.0];
    NSLog(@"radio test return 0x%08x result", result);
    
    FDRadioTestResult *radioTestResult = self.radioTestResult;
    if (!radioTestResult.pass) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio (incorrect response count v=%lu expected=%lu timeout=%@)", (unsigned long)radioTestResult.count, sizeof(bytes), radioTestResult.timeout ? @"YES" : @"NO"]];
        return NO;
    }
    if (radioTestResult.rssi < _radioTestStrength) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio strength (v=%0.1f min=%0.1f)", radioTestResult.rssi, _radioTestStrength]];
        return NO;
    }
    double speed = (sizeof(bytes) * 20) / radioTestResult.duration;
    if (speed < _radioTestSpeed) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio speed (v=%0.1f min=%0.1f)", speed, _radioTestSpeed]];
        return NO;
    }
    
    NSData *verifyData = [serialWireDebug readMemory:address length:sizeof(bytes)];
    if (![writeData isEqualToData:verifyData]) {
        [self addNote:notes message:[NSString stringWithFormat:@"check radio data (v=%@ expected=%@)", verifyData, writeData]];
        return NO;
    }
    
    return YES;
}

- (IBAction)test:(id)sender
{
    FDLog(@"Testing...");
    
    FDExecutable *executable = [self loadExecutable:@"RAM Debug" name:@"mp_test"];
    FDCortexM *cortexM = [self loadFirmwareIntoRam:executable];
    
    FDExecutableFunction *mp_test_set_blue_led = executable.functions[@"mp_test_set_blue_led"];
    [cortexM run:mp_test_set_blue_led.address r0:YES timeout:1.0];
}

- (void)usbHidMonitor:(FDUSBHIDMonitor *)monitor deviceAdded:(FDUSBHIDDevice *)device
{
    device.delegate = self;
    
    [_usbTableViewDataSource.devices addObject:device];
    [_usbTableView reloadData];
}

- (void)usbHidMonitor:(FDUSBHIDMonitor *)monitor deviceRemoved:(FDUSBHIDDevice *)device
{
    device.delegate = nil;
    
    [_usbTableViewDataSource.devices removeObject:device];
    [_usbTableView reloadData];
}

#define FD_SYNC_START 1
#define FD_SYNC_DATA 2
#define FD_SYNC_ACK 3

- (void)sync:(FDUSBHIDDevice *)device data:(NSData *)data
{
    NSURL *url = [NSURL URLWithString:@"http://localhost:5000/sync"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request addValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:data];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    uint8_t sequence_number = 0x00;
    uint16_t length = responseData.length;
    uint8_t bytes[] = {sequence_number, length, length >> 8};
    NSMutableData *ackData = [NSMutableData dataWithBytes:bytes length:sizeof(bytes)];
    [ackData appendData:responseData];
    [device setReport:ackData];
}

- (void)sensing:(NSData *)data
{
//    FDLog(@"sensing data received %@", data);
}

- (void)usbHidDevice:(FDUSBHIDDevice *)device inputReport:(NSData *)data
{
//    FDLog(@"inputReport %@", data);
    
    if (data.length < 1) {
        return;
    }
    
    uint8_t code = ((uint8_t *)data.bytes)[0];
    switch (code) {
        case FD_SYNC_DATA:
            [self sync:device data:data];
            break;
        case 0xff:
            [self sensing:data];
            break;
    }
}

- (FDUSBHIDDevice *)getSelectedUsbDevice
{
    NSInteger row = _usbTableView.selectedRow;
    if (row < 0) {
        return nil;
    }
    return [_usbTableViewDataSource.devices objectAtIndex:row];
}

- (IBAction)usbOpen:(id)sender
{
    FDUSBHIDDevice *device = [self getSelectedUsbDevice];
    [device open];
}

- (IBAction)usbClose:(id)sender
{
    FDUSBHIDDevice *device = [self getSelectedUsbDevice];
    [device close];
}

- (IBAction)usbWrite:(id)sender
{
    uint8_t sequence_number = 0x00;
    uint16_t length = 1;
    uint8_t bytes[] = {sequence_number, length, length >> 8, FD_SYNC_START};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    
    FDUSBHIDDevice *device = [self getSelectedUsbDevice];
    [device setReport:data];
}

- (void)fireflyIceSensing:(FDFireflyIce *)fireflyIce
                   ax:(float)ax ay:(float)ay az:(float)az
                   mx:(float)mx my:(float)my mz:(float)mz
{
    _axSlider.floatValue = ax;
    _aySlider.floatValue = ay;
    _azSlider.floatValue = az;
    
    _mxSlider.floatValue = mx;
    _mySlider.floatValue = my;
    _mzSlider.floatValue = mz;
}

- (FDFireflyIce *)getSelectedFireflyDevice
{
    NSInteger row = _bluetoothTableView.selectedRow;
    if (row < 0) {
        return nil;
    }
    return [_fireflyDevices objectAtIndex:row];
}

- (IBAction)bluetoothConnect:(id)sender
{
    FDFireflyIce *fireflyDevice = [self getSelectedFireflyDevice];
    [fireflyDevice.observable addObserver:self];
    FDFireflyIceChannelBLE * channel = (FDFireflyIceChannelBLE *)fireflyDevice.channels[@"BLE"];
    [_centralManager connectPeripheral:channel.peripheral options:nil];
}

- (IBAction)bluetoothDisconnect:(id)sender
{
    FDFireflyIce *fireflyDevice = [self getSelectedFireflyDevice];
    [fireflyDevice.observable removeObserver:self];
    FDFireflyIceChannelBLE * channel = (FDFireflyIceChannelBLE *)fireflyDevice.channels[@"BLE"];
    [_centralManager cancelPeripheralConnection:channel.peripheral];
}

- (IBAction)bluetoothWrite:(id)sender
{
//    FDFireflyIce *fireflyDevice = [self getSelectedFireflyDevice];
//    [fireflyDevice write];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _fireflyDevices.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return [[_fireflyDevices objectAtIndex:rowIndex] description];
}

- (void)centralManagerPoweredOn
{
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"310a0001-1b95-5091-b0bd-b7a681846399"]] options:nil];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStateUnknown:
        case CBCentralManagerStateResetting:
        case CBCentralManagerStateUnsupported:
        case CBCentralManagerStateUnauthorized:
            break;
        case CBCentralManagerStatePoweredOff:
            break;
        case CBCentralManagerStatePoweredOn:
            [self centralManagerPoweredOn];
            break;
    }
}

- (FDFireflyIce *)getFireflyDeviceByPeripheral:(CBPeripheral *)peripheral
{
    for (FDFireflyIce *fireflyDevice in _fireflyDevices) {
        FDFireflyIceChannelBLE *channel = (FDFireflyIceChannelBLE *)fireflyDevice.channels[@"BLE"];
        if (channel.peripheral == peripheral) {
            return fireflyDevice;
        }
    }
    return nil;
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    FDFireflyIce *fireflyDevice = [self getFireflyDeviceByPeripheral:peripheral];
    if (fireflyDevice != nil) {
        return;
    }
    
    FDLog(@"didDiscoverPeripheral %@", peripheral);
    fireflyDevice = [[FDFireflyIce alloc] init];
    FDFireflyIceChannelBLE *channel = [[FDFireflyIceChannelBLE alloc] initWithPeripheral:peripheral];
    [fireflyDevice addChannel:channel type:@"BLE"];
    [_fireflyDevices addObject:fireflyDevice];
    
    [_bluetoothTableView reloadData];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    FDLog(@"didConnectPeripheral %@", peripheral.name);
    FDFireflyIce *fireflyDevice = [self getFireflyDeviceByPeripheral:peripheral];
    FDFireflyIceChannelBLE *channel = (FDFireflyIceChannelBLE *)fireflyDevice.channels[@"BLE"];
    [channel didConnectPeripheral];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    FDLog(@"didDisconnectPeripheral %@ : %@", peripheral.name, error);
    FDFireflyIce *fireflyDevice = [self getFireflyDeviceByPeripheral:peripheral];
    FDFireflyIceChannelBLE *channel = (FDFireflyIceChannelBLE *)fireflyDevice.channels[@"BLE"];
    [channel didDisconnectPeripheralError:error];
}

@end