//
//  FDTargetOptionsView.m
//  FireflyProduction
//
//  Created by Denis Bohm on 11/3/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDTargetOptionsView.h"

@interface FDTargetOptionsView () <NSTextFieldDelegate, NSComboBoxDelegate>

@property (assign) IBOutlet NSTextField *bootAddressTextField;
@property (assign) IBOutlet NSTextField *bootNameTextField;
@property (assign) IBOutlet NSTextField *firmwareAddressTextField;
@property (assign) IBOutlet NSTextField *firmwareNameTextField;
@property (assign) IBOutlet NSTextField *metadataAddressTextField;
@property (assign) IBOutlet NSTextField *constantsAddressTextField;
@property (assign) IBOutlet NSTextField *constantsNameTextField;
@property (assign) IBOutlet NSPathControl *searchPathControl;
@property (assign) IBOutlet NSTextField *ramSizeTextField;
@property (assign) IBOutlet NSComboBox *processorComboBox;

@end

@implementation FDTargetOptionsView

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

- (NSString *)formatString:(NSString *)string
{
    return string == nil ? @"" : string;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    [self resourceChange:self];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
    [self resourceChange:self];
}

- (void)initialize
{
    [super initialize];
    
    _resources = [NSMutableDictionary dictionary];
    
    _bootAddressTextField.delegate = self;
    _bootNameTextField.delegate = self;
    _firmwareAddressTextField.delegate = self;
    _firmwareNameTextField.delegate = self;
    _metadataAddressTextField.delegate = self;
    _constantsAddressTextField.delegate = self;
    _constantsNameTextField.delegate = self;
    
    _ramSizeTextField.delegate = self;
    _processorComboBox.delegate = self;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:@"bootAddress"]) {
        _bootAddressTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"bootAddress"]];
        _bootNameTextField.stringValue = [userDefaults stringForKey:@"bootName"];
        _firmwareAddressTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"firmwareAddress"]];
        _firmwareNameTextField.stringValue = [userDefaults stringForKey:@"firmwareName"];
        _metadataAddressTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"metadataAddress"]];
        _constantsAddressTextField.stringValue = [self formatNumber:[userDefaults objectForKey:@"constantsAddress"]];
        _constantsNameTextField.stringValue = [self formatString:[userDefaults stringForKey:@"constantsName"]];
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
}

- (IBAction)setDefaults:(id)sender
{
    _bootAddressTextField.stringValue = @"0x0000";
    _bootNameTextField.stringValue = @"FireflyBoot";
    _firmwareAddressTextField.stringValue = @"0x8000";
    _firmwareNameTextField.stringValue = @"FireflyIce";
    _metadataAddressTextField.stringValue = @"0x7800";
    _constantsAddressTextField.stringValue = @"";
    _constantsNameTextField.stringValue = @"";
    NSString *searchPath = [NSString stringWithFormat:@"%@/sandbox/denisbohm/firefly-ice-firmware", NSHomeDirectory()];
    NSURL *URL = [NSURL fileURLWithPath:searchPath isDirectory:YES];
    _searchPathControl.URL = URL;
    _ramSizeTextField.stringValue = @"0x10000";
    [_processorComboBox selectItemWithObjectValue:@"EFM32"];
    
    [self resourceChange:self];
}

- (IBAction)resourceChange:(id)sender
{
    _resources[@"bootAddress"] = [self parseNumber:_bootAddressTextField.stringValue];
    _resources[@"bootName"] = _bootNameTextField.stringValue;
    _resources[@"firmwareAddress"] = [self parseNumber:_firmwareAddressTextField.stringValue];
    _resources[@"firmwareName"] = _firmwareNameTextField.stringValue;
    _resources[@"metadataAddress"] = [self parseNumber:_metadataAddressTextField.stringValue];
    _resources[@"constantsAddress"] = [self parseNumber:_constantsAddressTextField.stringValue];
    _resources[@"constantsName"] = _constantsNameTextField.stringValue;
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
    
    [_delegate targetOptionsViewChange:self];
}

@end
