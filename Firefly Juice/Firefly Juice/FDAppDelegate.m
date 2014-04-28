//
//  FDAppDelegate.m
//  Firefly Juice
//
//  Created by Denis Bohm on 4/27/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDAppDelegate.h"

#import "FDPowerSupply.h"
#import "FDSerialPort.h"

@interface FDAppDelegate () <FDPowerSupplyDelegate>

@property IBOutlet NSPopUpButton *serialPopUpButton;
@property IBOutlet NSTextField *identityTextField;
@property IBOutlet NSButton *outputPowerButton;
@property IBOutlet NSButton *overVoltageProtectionButton;
@property IBOutlet NSButton *overCurrentProtectionButton;
@property IBOutlet NSTextField *presetVoltageTextField;
@property IBOutlet NSTextField *presetCurrentTextField;
@property IBOutlet NSTextField *voltageTextField;
@property IBOutlet NSTextField *currentTextField;
@property IBOutlet NSTextField *bankTextField;
@property IBOutlet NSButton *beepButton;
@property IBOutlet NSButton *lockButton;

@property FDPowerSupply *powerSupply;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [_serialPopUpButton removeAllItems];
    NSMutableArray *serialPorts = [NSMutableArray arrayWithArray:[FDSerialPort findSerialPorts]];
    [serialPorts removeObject:@"/dev/cu.Bluetooth-Incoming-Port"];
    [serialPorts removeObject:@"/dev/cu.Bluetooth-Modem"];
    [_serialPopUpButton addItemsWithTitles:serialPorts];
    
    _powerSupply = [[FDPowerSupply alloc] init];
    _powerSupply.delegate = self;
}

- (IBAction)open:(id)sender
{
    NSString *path = _serialPopUpButton.titleOfSelectedItem;
    FDSerialPort *serialPort = [[FDSerialPort alloc] init];
    serialPort.path = path;
    
    _powerSupply.serialPort = serialPort;
    [_powerSupply open];
}

- (IBAction)close:(id)sender
{
    [_powerSupply close];
}

- (IBAction)getStatus:(id)sender
{
    [_powerSupply getStatus];
}

- (void)powerSupply:(FDPowerSupply *)powerSupply status:(FDPowerSupplyStatus *)status
{
    _outputPowerButton.state = status.output ?  NSOnState : NSOffState;
    _overVoltageProtectionButton.state = status.overVoltageProtection ? NSOnState : NSOffState;
    _overCurrentProtectionButton.state = status.overCurrentProtection ? NSOnState : NSOffState;
    
    FDPowerSupplyChannel *channel = status.channels[0];
    _presetVoltageTextField.stringValue = [NSString stringWithFormat:@"%0.2f", channel.presetVoltage];
    _presetCurrentTextField.stringValue = [NSString stringWithFormat:@"%0.3f", channel.presetCurrent];
    _voltageTextField.stringValue = [NSString stringWithFormat:@"%0.2f", channel.voltage];
    _currentTextField.stringValue = [NSString stringWithFormat:@"%0.2f", channel.current];
}

- (IBAction)recall:(id)sender
{
    int bank = [_bankTextField.stringValue intValue];
    [_powerSupply recall:bank];
}

- (IBAction)save:(id)sender
{
    int bank = [_bankTextField.stringValue intValue];
    [_powerSupply save:bank];
}

- (IBAction)beep:(id)sender
{
    BOOL enabled = _beepButton.state == NSOnState;
    [_powerSupply beep:enabled];
}

- (IBAction)lock:(id)sender
{
    BOOL enabled = _lockButton.state == NSOnState;
    [_powerSupply lock:enabled];
}

- (IBAction)setPresetVoltage:(id)sender
{
    float voltage = [_presetVoltageTextField.stringValue floatValue];
    [_powerSupply setPreset:1 voltage:voltage];
}

- (IBAction)setPresetCurrent:(id)sender
{
    float current = [_presetCurrentTextField.stringValue floatValue];
    [_powerSupply setPreset:1 current:current];
}

@end