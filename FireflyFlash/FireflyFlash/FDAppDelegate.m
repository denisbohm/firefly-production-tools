//
//  FDAppDelegate.m
//  FireflyFlash
//
//  Created by Denis Bohm on 4/30/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"

#import <FireflyProduction/FDExecutable.h>
#import <FireflyProduction/FDFireflyDevice.h>
#import <FireflyProduction/FDGdbServer.h>
#import <FireflyProduction/FDGdbServerSwd.h>
#import <FireflyProduction/FDUSBHIDMonitor.h>

#import <ARMSerialWireDebug/FDCortexM.h>
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

@interface FDAppDelegate () <CBCentralManagerDelegate, FDUSBMonitorDelegate, FDUSBHIDMonitorDelegate, FDUSBHIDDeviceDelegate, FDFireflyDeviceDelegate, NSTableViewDataSource>

@property (assign) IBOutlet NSTableView *bluetoothTableView;
@property CBCentralManager *centralManager;
@property NSMutableArray *fireflyDevices;

@property (assign) IBOutlet NSTableView *usbTableView;
@property FDUSBHIDMonitor *usbMonitor;
@property FDUSBTableViewDataSource *usbTableViewDataSource;

@property (assign) IBOutlet NSTableView *swdTableView;
@property FDUSBMonitor *swdMonitor;
@property FDUSBTableViewDataSource *swdTableViewDataSource;

@property (assign) IBOutlet NSSlider *axSlider;
@property (assign) IBOutlet NSSlider *aySlider;
@property (assign) IBOutlet NSSlider *azSlider;

@property (assign) IBOutlet NSSlider *mxSlider;
@property (assign) IBOutlet NSSlider *mySlider;
@property (assign) IBOutlet NSSlider *mzSlider;

@property FDGdbServer *gdbServer;
@property FDGdbServerSwd *gdbServerSwd;

@property NSString *elf;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //    _elf = @"/Users/denis/sandbox/denisbohm/firefly-ice-firmware/THUMB Flash Release/FireflyIce.elf";
    _elf = @"/Users/denis/sandbox/denisbohm/firefly-ice-firmware/bin/FireflyIce.elf";
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:_elf];
    for (FDExecutableSection *section in executable.sections) {
        NSLog(@"type = %d, address = 0x%08x, length = %ld", section.type, section.address, section.data.length);
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
    _swdMonitor.vendor = 0x15ba;
    _swdMonitor.product = 0x002a;
    _swdMonitor.delegate = self;
    _swdTableViewDataSource = [[FDUSBTableViewDataSource alloc] init];
    _swdTableView.dataSource = _swdTableViewDataSource;
    
    [_usbMonitor start];
    [_swdMonitor start];
    
    _gdbServer = [[FDGdbServer alloc] init];
    _gdbServerSwd = [[FDGdbServerSwd alloc] init];
    _gdbServer.delegate = _gdbServerSwd;
    _gdbServerSwd.gdbServer = _gdbServer;
    [_gdbServer start];
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceAdded:(FDUSBDevice *)device
{
    [_swdTableViewDataSource.devices addObject:device];
    [_swdTableView reloadData];
}

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceRemoved:(FDUSBDevice *)device
{
    [_swdTableViewDataSource.devices removeObject:device];
    [_swdTableView reloadData];
}

- (FDUSBDevice *)getSelectedSwdDevice
{
    NSInteger row = _swdTableView.selectedRow;
    if (row < 0) {
        return nil;
    }
    return [_swdTableViewDataSource.devices objectAtIndex:row];
}

#define EnergyMicro_DebugPort_IdentifcationCode 0x2ba01477

- (IBAction)swdConnect:(id)sender
{
    FDUSBDevice *usbDevice = [self getSelectedSwdDevice];
    [usbDevice open];
    FDSerialEngine *serialEngine = [[FDSerialEngine alloc] init];
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
    
    [serialWireDebug resetDebugAccessPort];
    uint32_t debugPortIDCode = [serialWireDebug readDebugPortIDCode];
    NSLog(@"DPID = %08x", debugPortIDCode);
    if (debugPortIDCode != EnergyMicro_DebugPort_IdentifcationCode) {
        NSLog(@"unexpected debug port identification code");
    }
    [serialWireDebug initializeDebugAccessPort];
    NSLog(@"read CPU ID");
    uint32_t cpuID = [serialWireDebug readCPUID];
    NSLog(@"CPUID = %08x", cpuID);
    if ((cpuID & 0xfffffff0) == 0x412FC230) {
        uint32_t n = cpuID & 0x0000000f;
        NSLog(@"ARM Cortex-M3 r2p%d", n);
    }
    
    [serialWireDebug halt];
    
    _gdbServerSwd.serialWireDebug = serialWireDebug;
}

/*
 - (IBAction)swdTest:(id)sender
 NSLog(@"write memory");
 uint32_t address = 0x20000000;
 [serialWireDebug writeMemory:address value:0x01234567];
 [serialWireDebug checkDebugPortStatus];
 [serialWireDebug writeMemory:address + 4 value:0x76543210];
 NSLog(@"read memory");
 uint32_t m0 = [serialWireDebug readMemory:address];
 uint32_t m1 = [serialWireDebug readMemory:address+4];
 NSLog(@"m0 = %08x, m1 = %08x", m0, m1);
 
 NSLog(@"write register");
 [serialWireDebug writeRegister:0 value:0x01234567];
 [serialWireDebug writeRegister:1 value:0x76543210];
 NSLog(@"read register");
 uint32_t r0 = [serialWireDebug readRegister:0];
 uint32_t r1 = [serialWireDebug readRegister:1];
 NSLog(@"r0 = %08x, r1 = %08x", r0, r1);
 
 NSLog(@"bluk memory read/write");
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
 NSLog(@"pass write = %0.1f Bps, read = %0.1f Bps", writeBps, readBps);
 } else {
 NSLog(@"fail");
 NSLog(@"data = %@", data);
 NSLog(@"output = %@", output);
 }
 
 NSLog(@"erase & program");
 address = 0x00000000;
 [serialWireDebug erase:address];
 before = [NSDate date];
 [serialWireDebug program:address data:data];
 after = [NSDate date];
 double programBps = data.length / [after timeIntervalSinceDate:before];
 NSData *readData = [serialWireDebug readMemory:address length:(UInt32)data.length];
 if ([data isEqualToData:readData]) {
 NSLog(@"pass program = %0.1f Bps", programBps);
 } else {
 NSLog(@"fail");
 NSLog(@"data = %@", data);
 NSLog(@"output = %@", readData);
 }
 }
 */

- (IBAction)swdProgram:(id)sender
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    
    NSLog(@"reading executable");
    FDExecutable *executable = [[FDExecutable alloc] init];
    [executable load:_elf];
    NSLog(@"mass erase");
    [serialWireDebug massErase];
    for (FDExecutableSection *section in executable.sections) {
        switch (section.type) {
            case FDExecutableSectionTypeProgram: {
                NSLog(@"loading flash");
                [serialWireDebug program:section.address data:section.data];
                NSData *verify = [serialWireDebug readMemory:section.address length:(uint32_t)section.data.length];
                if ([section.data isEqualToData:verify]) {
                    NSLog(@"flash verified");
                } else {
                    NSLog(@"flash program failure");
                }
            } break;
            case FDExecutableSectionTypeData:
                NSLog(@"loading RAM");
                [serialWireDebug writeMemory:section.address data:section.data];
                break;
        }
    }
    NSLog(@"resetting");
    [serialWireDebug reset];
    //    [serialWireDebug run];
    
    /*
     FDExecutableFunction *function = executable.functions[@"test_led"];
     FDCortexM *cortexM = [[FDCortexM alloc] init];
     cortexM.serialWireDebug = serialWireDebug;
     [cortexM run:function.address timeout:1.0];
     */
}

- (IBAction)swdReset:(id)sender
{
    FDSerialWireDebug *serialWireDebug = _gdbServerSwd.serialWireDebug;
    
    [serialWireDebug halt];
    [serialWireDebug reset];
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
    NSLog(@"sensing data received %@", data);
}

- (void)usbHidDevice:(FDUSBHIDDevice *)device inputReport:(NSData *)data
{
    NSLog(@"inputReport %@", data);
    
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

- (void)fireflyDevice:(FDFireflyDevice *)fireflyDevice
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

- (FDFireflyDevice *)getSelectedFireflyDevice
{
    NSInteger row = _bluetoothTableView.selectedRow;
    if (row < 0) {
        return nil;
    }
    return [_fireflyDevices objectAtIndex:row];
}

- (IBAction)bluetoothConnect:(id)sender
{
    FDFireflyDevice *fireflyDevice = [self getSelectedFireflyDevice];
    fireflyDevice.delegate = self;
    [_centralManager connectPeripheral:fireflyDevice.peripheral options:nil];
}

- (IBAction)bluetoothDisconnect:(id)sender
{
    FDFireflyDevice *fireflyDevice = [self getSelectedFireflyDevice];
    fireflyDevice.delegate = nil;
    [_centralManager cancelPeripheralConnection:fireflyDevice.peripheral];
}

- (IBAction)bluetoothWrite:(id)sender
{
    FDFireflyDevice *fireflyDevice = [self getSelectedFireflyDevice];
    [fireflyDevice write];
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

- (FDFireflyDevice *)getFireflyDeviceByPeripheral:(CBPeripheral *)peripheral
{
    for (FDFireflyDevice *fireflyDevice in _fireflyDevices) {
        if (fireflyDevice.peripheral == peripheral) {
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
    FDFireflyDevice *fireflyDevice = [self getFireflyDeviceByPeripheral:peripheral];
    if (fireflyDevice != nil) {
        return;
    }
    
    NSLog(@"didDiscoverPeripheral %@", peripheral);
    fireflyDevice = [[FDFireflyDevice alloc] initWithPeripheral:peripheral];
    [_fireflyDevices addObject:fireflyDevice];
    
    [_bluetoothTableView reloadData];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral %@", peripheral.name);
    FDFireflyDevice *fireflyDevice = [self getFireflyDeviceByPeripheral:peripheral];
    [fireflyDevice didConnectPeripheral];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didDisconnectPeripheral %@ : %@", peripheral.name, error);
    FDFireflyDevice *fireflyDevice = [self getFireflyDeviceByPeripheral:peripheral];
    [fireflyDevice didDisconnectPeripheralError:error];
}


@end