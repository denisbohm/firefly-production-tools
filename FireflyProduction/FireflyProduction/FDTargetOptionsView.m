//
//  FDTargetOptionsView.m
//  FireflyProduction
//
//  Created by Denis Bohm on 11/3/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDTargetOptionsView.h"

@interface FDTargetOptionsView () <NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate, NSComboBoxDelegate>

@property NSMutableArray *targets;

@property (assign) IBOutlet NSOutlineView *outlineView;
@property (assign) IBOutlet NSButton *addButton;
@property (assign) IBOutlet NSButton *removeButton;

@property (assign) IBOutlet NSTextField *bootloaderNameTextField;
@property (assign) IBOutlet NSTextField *bootloaderAddressTextField;
@property (assign) IBOutlet NSTextField *bootloaderMetadataAddressTextField;
@property (assign) IBOutlet NSTextField *applicationNameTextField;
@property (assign) IBOutlet NSTextField *applicationAddressTextField;
@property (assign) IBOutlet NSTextField *applicationMetadataAddressTextField;
@property (assign) IBOutlet NSTextField *operatingSystemNameTextField;
@property (assign) IBOutlet NSTextField *operatingSystemAddressTextField;
@property (assign) IBOutlet NSTextField *operatingSystemMetadataAddressTextField;
@property (assign) IBOutlet NSPathControl *searchPathControl;
@property (assign) IBOutlet NSTextField *ramSizeTextField;
@property (assign) IBOutlet NSComboBox *processorComboBox;

@end

@implementation FDTargetOptionsView

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn
             byItem:(id)item
{
    NSInteger index = [_targets indexOfObject:item];
    [_targets replaceObjectAtIndex:index withObject:object];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *oldTargets = [userDefaults valueForKey:@"targets"];
    NSDictionary *oldTarget = oldTargets[index];
    NSMutableDictionary *target = [NSMutableDictionary dictionaryWithDictionary:oldTarget];
    target[@"name"] = object;
    NSMutableArray *targets = [NSMutableArray arrayWithArray:oldTargets];
    [targets replaceObjectAtIndex:index withObject:target];
    [userDefaults setObject:targets forKey:@"targets"];
    [userDefaults synchronize];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) { //item is nil when the outline view wants to inquire for root level items
        return _targets.count;
    }
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (item == nil) { //item is nil when the outline view wants to inquire for root level items
        return _targets[index];
    }
    return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item
{
    return item;
}

/*
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(NSTreeNode*)item
{
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
    cellView.textField.stringValue = (NSString *)item;
    return cellView;
}
*/

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
    
    _outlineView.delegate = self;
    _outlineView.dataSource = self;
    
    _bootloaderNameTextField.delegate = self;
    _bootloaderAddressTextField.delegate = self;
    _bootloaderMetadataAddressTextField.delegate = self;
    _applicationNameTextField.delegate = self;
    _applicationAddressTextField.delegate = self;
    _applicationMetadataAddressTextField.delegate = self;
    _operatingSystemNameTextField.delegate = self;
    _operatingSystemAddressTextField.delegate = self;
    _operatingSystemMetadataAddressTextField.delegate = self;
    
    _ramSizeTextField.delegate = self;
    _processorComboBox.delegate = self;
    
    [self loadTargets];
    if (_targets.count == 0) {
        [self setDefaults:self];
    }
}

- (void)loadTargets
{
    _targets = [NSMutableArray array];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *targets = [userDefaults objectForKey:@"targets"];
    for (NSDictionary *target in targets) {
        NSString *name = target[@"name"];
        [_targets addObject:name];
    }
    [_outlineView reloadData];
    
    if (targets.count <= 0) {
        return;
    }
    
    [_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (NSDictionary *)targetFromUserDefaults:(NSString *)name
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *targets = [userDefaults objectForKey:@"targets"];
    for (NSDictionary *target in targets) {
        if ([target[@"name"] isEqualToString:name]) {
            return target;
        }
    }
    return nil;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger index = _outlineView.selectedRow;
    if (index < 0) {
        return;
    }
    
    NSString *targetName = _targets[index];
    NSDictionary *target = [self targetFromUserDefaults:targetName];
    
    NSDictionary *application = target[@"application"];
    _applicationNameTextField.stringValue = [self formatString:application[@"firmwareName"]];
    _applicationAddressTextField.stringValue = [self formatString:application[@"firmwareAddress"]];
    _applicationMetadataAddressTextField.stringValue = [self formatString:application[@"metadataAddress"]];
    
    NSDictionary *bootloader = target[@"bootloader"];
    _bootloaderNameTextField.stringValue = [self formatString:bootloader[@"firmwareName"]];
    _bootloaderAddressTextField.stringValue = [self formatString:bootloader[@"firmwareAddress"]];
    _bootloaderMetadataAddressTextField.stringValue = [self formatString:bootloader[@"metadataAddress"]];
    
    NSDictionary *operatingSystem = target[@"operatingSystem"];
    _operatingSystemNameTextField.stringValue = [self formatString:operatingSystem[@"firmwareName"]];
    _operatingSystemAddressTextField.stringValue = [self formatString:operatingSystem[@"firmwareAddress"]];
    _operatingSystemMetadataAddressTextField.stringValue = [self formatString:operatingSystem[@"metadataAddress"]];
    
    @try {
        NSString *searchPath = target[@"searchPath"];
        if (searchPath != nil) {
            NSURL *URL = [NSURL fileURLWithPath:searchPath];
            if ([URL isFileURL]) {
                _searchPathControl.URL = URL;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"cannot set search path: %@", e);
    }
    
    [_processorComboBox selectItemWithObjectValue:target[@"processor"]];
    
    _ramSizeTextField.stringValue = [self formatString:target[@"ramSize"]];
    
    [self resourceChange:self];
}

- (IBAction)setDefaults:(id)sender
{
    NSArray *targets = @[
                         @{
                             @"name": @"Firefly Ice",
                             @"application": @{
                                     @"firmwareName": @"FireflyIce",
                                     @"firmwareAddress": @"0x8000",
                                     @"metadataAddress": @"0x7800",
                                     },
                             @"bootloader": @{
                                     @"firmwareName": @"FireflyBoot",
                                     @"firmwareAddress": @"0x0000",
                                     @"metadataAddress": @"",
                                     },
                             @"operatingSystem": @{
                                     @"firmwareName": @"",
                                     @"firmwareAddress": @"",
                                     @"metadataAddress": @"",
                                     },
                             @"searchPath": @"~/sandbox/denisbohm/firefly-ice-firmware",
                             @"processor": @"EFM32",
                             @"ramSize": @"0x10000",
                             },
                         @{
                             @"name": @"Atlas STM",
                             @"application": @{
                                     @"firmwareName": @"aw_stm",
                                     @"firmwareAddress": @"0x0800C000",
                                     @"metadataAddress": @"0x08004000",
                                     },
                             @"bootloader": @{
                                     @"firmwareName": @"aw_stm_boot",
                                     @"firmwareAddress": @"0x08000000",
                                     @"metadataAddress": @"",
                                     },
                             @"operatingSystem": @{
                                     @"firmwareName": @"",
                                     @"firmwareAddress": @"",
                                     @"metadataAddress": @"",
                                     },
                             @"searchPath": @"~/sandbox/atlas/firmware",
                             @"processor": @"STM32F4",
                             @"ramSize": @"0x10000",
                             },
                         @{
                             @"name": @"Atlas NRF",
                             @"application": @{
                                     @"firmwareName": @"aw_nrf",
                                     @"firmwareAddress": @"0x16000",
                                     @"metadataAddress": @"0x37800",
                                     },
                             @"bootloader": @{
                                     @"firmwareName": @"aw_nrf_boot",
                                     @"firmwareAddress": @"0x38000",
                                     @"metadataAddress": @"0x37C00",
                                     },
                             @"operatingSystem": @{
                                     @"firmwareName": @"s110_nrf51822_7.0.0",
                                     @"firmwareAddress": @"0x00000",
                                     @"metadataAddress": @"",
                                     },
                             @"searchPath": @"~/sandbox/atlas/firmware",
                             @"processor": @"NRF51",
                             @"ramSize": @"0x10000",
                             },
                         ];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:targets forKey:@"targets"];
    
    [self loadTargets];
}

- (NSNumber *)parseNumber:(NSString *)text
{
    @try {
        if ([text hasPrefix:@"0x"]) {
            NSScanner *scanner = [NSScanner scannerWithString:text];
            unsigned long long temp;
            [scanner scanHexLongLong:&temp];
            return [NSNumber numberWithLongLong:temp];
        }
        return [NSNumber numberWithLongLong:[text longLongValue]];
    } @catch (NSException *e) {
        return @0;
    }
}

- (id)convertToResouce:(NSString *)key value:(id)value
{
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = (NSString *)value;
        if (string.length == 0) {
            return nil;
        }
    }
    
    if ([key hasSuffix:@"Size"] || [key hasSuffix:@"Address"]) {
        return [self parseNumber:(NSString *)value];
    }
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [value enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
            id resourceValue = [self convertToResouce:(NSString *)key value:value];
            if (resourceValue != nil) {
                dictionary[key] = resourceValue;
            }
        }];
        return dictionary;
    }
    
    return value;
}

- (IBAction)resourceChange:(id)sender
{
    NSInteger index = _outlineView.selectedRow;
    if (index < 0) {
        _resources = [NSMutableDictionary dictionary];
        return;
    }
    
    NSString *targetName = _targets[index];
    NSDictionary *target = @{
      @"name": targetName,
      @"application": @{
              @"firmwareName": _applicationNameTextField.stringValue,
              @"firmwareAddress": _applicationAddressTextField.stringValue,
              @"metadataAddress": _applicationMetadataAddressTextField.stringValue,
              },
      @"bootloader": @{
              @"firmwareName": _bootloaderNameTextField.stringValue,
              @"firmwareAddress": _bootloaderAddressTextField.stringValue,
              @"metadataAddress": _bootloaderMetadataAddressTextField.stringValue,
              },
      @"operatingSystem": @{
              @"firmwareName": _operatingSystemNameTextField.stringValue,
              @"firmwareAddress": _operatingSystemAddressTextField.stringValue,
              @"metadataAddress": _operatingSystemMetadataAddressTextField.stringValue,
              },
      @"searchPath": _searchPathControl.URL.path,
      @"processor": _processorComboBox.objectValueOfSelectedItem,
      @"ramSize": _ramSizeTextField.stringValue,
      };
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *oldTargets = [userDefaults valueForKey:@"targets"];
    NSMutableArray *targets = [NSMutableArray arrayWithArray:oldTargets];
    for (NSInteger i = 0; i < targets.count; ++i) {
        NSDictionary *oldTarget = targets[i];
        NSString *name = oldTarget[@"name"];
        if ([name isEqualToString:targetName]) {
            [targets replaceObjectAtIndex:i withObject:target];
            break;
        }
    }
    [userDefaults setObject:targets forKey:@"targets"];
    [userDefaults synchronize];
    
    _resources = [self convertToResouce:@"" value:target];
    
    [_delegate targetOptionsViewChange:self];
}

- (IBAction)addTarget:(id)sender
{
    NSString *name = @"myApp";
    NSSet *names = [NSMutableSet setWithArray:_targets];
    for (NSInteger i = 1; i < 100; ++i) {
        if (![names containsObject:name]) {
            break;
        }
        name = [NSString stringWithFormat:@"myApp %ld", (long)i];
    }
    NSDictionary *target = @{
                             @"name": name,
                             @"application": @{
                                     @"firmwareName": @"myApp",
                                     @"firmwareAddress": @"0x00000000",
                                     @"metadataAddress": @"",
                                     },
                             @"bootloader": @{
                                     @"firmwareName": @"",
                                     @"firmwareAddress": @"",
                                     @"metadataAddress": @"",
                                     },
                             @"operatingSystem": @{
                                     @"firmwareName": @"",
                                     @"firmwareAddress": @"",
                                     @"metadataAddress": @"",
                                     },
                             @"searchPath": @"~/",
                             @"processor": @"EFM32",
                             @"ramSize": @"0x8000",
                             };

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *oldTargets = [userDefaults valueForKey:@"targets"];
    NSMutableArray *targets = [NSMutableArray arrayWithArray:oldTargets];
    [targets addObject:target];
    [userDefaults setObject:targets forKey:@"targets"];
    [userDefaults synchronize];
    [self loadTargets];
}

- (IBAction)removeTarget:(id)sender
{
    NSInteger index = _outlineView.selectedRow;
    if (index < 0) {
        return;
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *oldTargets = [userDefaults valueForKey:@"targets"];
    NSMutableArray *targets = [NSMutableArray arrayWithArray:oldTargets];
    [targets removeObjectAtIndex:index];
    [userDefaults setObject:targets forKey:@"targets"];
    [userDefaults synchronize];
    [self loadTargets];
}

@end
