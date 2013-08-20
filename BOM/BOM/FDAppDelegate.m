//
//  FDAppDelegate.m
//  BOM
//
//  Created by Denis Bohm on 5/16/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"
#import "FDBillOfMaterials.h"

@interface FDOptionDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

@property NSMutableArray *options;

@end;

@implementation FDOptionDataSource

- (id)init
{
    if (self = [super init]) {
        _options = [NSMutableArray array];
    }
    return self;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)object
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex
{
    FDOption *option = _options[rowIndex];
    option.value = [object boolValue];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _options.count;
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex
{
    FDOption *option = _options[rowIndex];
    NSButtonCell *buttonCell = (NSButtonCell *)cell;
    [buttonCell setTitle:option.title];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    FDOption *option = _options[rowIndex];
    return [NSNumber numberWithBool:option.value];
}

@end

@interface FDAppDelegate ()

@property (assign) IBOutlet NSPathControl *schematicPathControl;
@property (assign) IBOutlet NSTableView *optionsTableView;
@property (assign) IBOutlet NSTableView *sellersTableView;
@property (assign) IBOutlet NSComboBox *qty1ComboBox;
@property (assign) IBOutlet NSComboBox *qty2ComboBox;
@property (assign) IBOutlet NSComboBox *qty3ComboBox;
@property (assign) IBOutlet NSTextField *price1Label;
@property (assign) IBOutlet NSTextField *price2Label;
@property (assign) IBOutlet NSTextField *price3Label;

@property FDOptionDataSource *optionDataSource;
@property FDOptionDataSource *sellerDataSource;

@property FDBillOfMaterials *bom;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *schematicPath = [userDefaults stringForKey:@"schematicPath"];
    if (schematicPath) {
        _schematicPathControl.URL = [[NSURL alloc] initFileURLWithPath:schematicPath];
    }
    
    _optionDataSource = [[FDOptionDataSource alloc] init];
    [_optionsTableView setDataSource:_optionDataSource];
    _optionsTableView.delegate = _optionDataSource;
    
    _sellerDataSource = [[FDOptionDataSource alloc] init];
    [_sellersTableView setDataSource:_sellerDataSource];
    _sellersTableView.delegate = _sellerDataSource;
    
    [_price1Label setSelectable:YES];
    [_price2Label setSelectable:YES];
    [_price3Label setSelectable:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSString *schematicPath = _schematicPathControl.URL.path;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:schematicPath forKey:@"schematicPath"];
}

- (NSNumber *)comboBoxNumber:(NSComboBox *)comboBox
{
    NSString *value = [comboBox objectValue];
    return [NSNumber numberWithInteger:[value integerValue]];
}

- (IBAction)loadOptions:(id)sender
{
    FDBillOfMaterials *bom = [[FDBillOfMaterials alloc] init];
    NSString *schematicPath = _schematicPathControl.URL.path;
    bom.schematicPath = schematicPath;
    NSArray *titles = [bom readOptions];
    NSMutableArray *options = [NSMutableArray array];
    for (NSString *title in titles) {
        [options addObject:[FDOption option:title value:YES]];
    }
    _optionDataSource.options = options;
    [_optionsTableView reloadData];
    
    NSNumber *qty1 = [self comboBoxNumber:_qty1ComboBox];
    NSNumber *qty2 = [self comboBoxNumber:_qty2ComboBox];
    NSNumber *qty3 = [self comboBoxNumber:_qty3ComboBox];
    bom.quantities = @[qty1, qty2, qty3];
    [bom read];
    [bom getPricingAndAvailability];
    
    NSMutableSet *sellerNameSet = [NSMutableSet set];
    for (FDBuy *buy in bom.buys) {
        for (FDPartBuy *partBuy in buy.partBuys) {
            if (partBuy.seller != nil) {
                [sellerNameSet addObject:partBuy.seller.name];
            }
            for (FDPartBuy *partialPartBuy in partBuy.partialPartBuys) {
                [sellerNameSet addObject:partialPartBuy.seller.name];
            }
        }
    }
    NSArray *sellerNames = [[sellerNameSet allObjects] sortedArrayUsingSelector:@selector(localizedCompare:)];
    NSMutableArray *sellerOptions = [NSMutableArray array];
    for (NSString *sellerName in sellerNames) {
        [sellerOptions addObject:[FDOption option:sellerName value:YES]];
    }
    _sellerDataSource.options = sellerOptions;
    [_sellersTableView reloadData];
}

- (void)read
{
    NSString *schematicPath = _schematicPathControl.URL.path;
    if (!schematicPath) {
        return;
    }
    
    _bom = [[FDBillOfMaterials alloc] init];
    _bom.schematicPath = schematicPath;
    NSMutableSet *options =[[NSMutableSet alloc] init];
    for (FDOption *option in _optionDataSource.options) {
        [options addObject:option.value ? option.title : [NSString stringWithFormat:@"!%@", option.title]];
    }
    _bom.options = options;
    NSNumber *qty1 = [self comboBoxNumber:_qty1ComboBox];
    NSNumber *qty2 = [self comboBoxNumber:_qty2ComboBox];
    NSNumber *qty3 = [self comboBoxNumber:_qty3ComboBox];
    _bom.quantities = @[qty1, qty2, qty3];
    [_bom read];
}

- (void)setPriceDescription:(NSTextField *)label buy:(FDBuy *)buy
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"$%0.2f/ea ($%0.2f)", buy.price / buy.quantity, buy.price];
    if (buy.lowStockItems.count > 0) {
        [description appendString:@" "];
        NSUInteger indexBefore = [description length];
        if (buy.leadDays > 0) {
            [description appendFormat:@"%@ ETA", [FDBillOfMaterials eta:buy.leadDays]];
        } else {
            [description appendFormat:@"??? ETA"];
        }
        NSUInteger indexAfter = [description length];
        NSRange range = NSMakeRange(indexBefore, indexAfter - indexBefore);
        [description appendFormat:@" (%lu stock issues)", (unsigned long)buy.lowStockItems.count];
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:description];
        [string addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:range];
        [label setAttributedStringValue:string];
    } else {
        [label setStringValue:description];
    }
}

- (IBAction)loadPricing:(id)sender
{
    [self read];
    
    NSMutableSet *options =[[NSMutableSet alloc] init];
    for (FDOption *option in _sellerDataSource.options) {
        if (option.value) {
            [options addObject:option.title];
        }
    }
    _bom.sellers = options;
    [_bom getPricingAndAvailability];
    [self setPriceDescription:_price1Label buy:_bom.buys[0]];
    [self setPriceDescription:_price2Label buy:_bom.buys[1]];
    [self setPriceDescription:_price3Label buy:_bom.buys[2]];
    
    [_bom exportBuys];
}

- (IBAction)generateAll:(id)sender
{
    [self read];
    
    [_bom exportForScreamingCircuits];
}

@end
