//
//  FDAppDelegate.m
//  FireflyRML
//
//  Created by Denis Bohm on 12/5/13.
//  Copyright (c) 2013 Firefly Design LLC. All rights reserved.
//

#import "FDAppDelegate.h"

#import "FDRML.h"
#import "FDSerialPort.h"

@interface FDAppDelegate () <FDSerialPortDelegate>

@property IBOutlet NSPopUpButton *serialPopUpButton;

@property FDSerialPort *serialPort;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [_serialPopUpButton removeAllItems];
    NSMutableArray *serialPorts = [NSMutableArray arrayWithArray:[FDSerialPort findSerialPorts]];
    [serialPorts removeObject:@"/dev/cu.Bluetooth-Incoming-Port"];
    [serialPorts removeObject:@"/dev/cu.Bluetooth-Modem"];
    [_serialPopUpButton addItemsWithTitles:serialPorts];
}

- (void)serialPort:(FDSerialPort *)serialPort didReceiveData:(NSData *)data
{
    NSLog(@"serial port received data: '%@'", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
}

- (void)writeRML:(FDRML *)rml
{
    NSLog(@"serial port transmit data: %@", [[NSString alloc] initWithData:rml.data encoding:NSASCIIStringEncoding]);
    [_serialPort writeData:rml.data];
}

- (IBAction)mdxOpen:(id)sender
{
    NSString *path = _serialPopUpButton.titleOfSelectedItem;
    _serialPort = [[FDSerialPort alloc] init];
    _serialPort.path = path;
    _serialPort.delegate = self;
    _serialPort.baudRate = 9600;
    // Bit rate of 9,600, no parity, one data bit, stop bit 8, and hardware handshaking
    [_serialPort open];
}

- (IBAction)mdxStart:(id)sender
{
    FDRML *rml = [[FDRML alloc] init];
    [rml rmlReset];
    [rml rmlInitialize];
    [rml rmlMotorControl:YES];
    [rml rmlPlotRelative];
    [rml rmlVelocityZ:15];
    [rml rmlMove:RMLMakePoint(0, 0, 0)];
    [rml rmlPlotAbsolute];
    [self writeRML:rml];
}

- (IBAction)mdxCut:(id)sender
{
    FDRML *rml = [[FDRML alloc] init];
    [rml rmlMove:RMLMakePoint(0, 0, 0)];
    [rml rmlMove:RMLMakePoint(50, 50, -50)];
    [self writeRML:rml];
}

- (IBAction)mdxStop:(id)sender
{
    FDRML *rml = [[FDRML alloc] init];
    [rml rmlMotorControl:NO];
    [rml rmlPlotRelative];
    [rml rmlVelocityZ:15];
    [rml rmlMove:RMLMakePoint(0, 0, 0)];
    [rml rmlInitialize];
    [self writeRML:rml];
}

- (IBAction)mdxAbort:(id)sender
{
    [_serialPort purge];
    FDRML *rml = [[FDRML alloc] init];
    [rml rmlAbort];
    [self writeRML:rml];
}

- (IBAction)mdxQuery:(id)sender
{
    FDRML *rml = [[FDRML alloc] init];
//    [rml rmlOutputErrorCode];
//    [rml rmlOutputBufferSize];
    [rml rmlOutputRemainingBufferCapacity];
    [self writeRML:rml];
}

- (IBAction)mdxClose:(id)sender
{
    [_serialPort close];
    _serialPort = nil;
}

@end
