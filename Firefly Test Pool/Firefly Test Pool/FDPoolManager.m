//
//  FDPoolManager.m
//  Firefly Test Pool
//
//  Created by Denis Bohm on 4/18/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDPoolManager.h"

#import "FDPoolMember.h"
#import "FDPoolTableViewDataSource.h"

#import <FireflyDevice/FDExecutor.h>
#import <FireflyDevice/FDFireflyIce.h>
#import <FireflyDevice/FDFireflyIceChannelBLE.h>
#import <FireflyDevice/FDFireflyIceCoder.h>
#import <FireflyDevice/FDFireflyIceSimpleTask.h>
#import <FireflyDevice/FDFirmwareUpdateTask.h>
#import <FireflyDevice/FDHelloTask.h>

@interface FDPoolManager () <CBCentralManagerDelegate, FDFireflyIceObserver, FDHelloTaskDelegate, FDExecutorObserver>

@property NSTableView *tableView;
@property(readonly) FDPoolTableViewDataSource *dataSource;

@property CBCentralManager *centralManager;

@property CBUUID *service;

@end

@implementation FDPoolManager

- (id)initWithTableView:(NSTableView *)tableView
{
    if (self = [super init]) {
        _tableView = tableView;
        _dataSource = [[FDPoolTableViewDataSource alloc] init];
        _tableView.dataSource = _dataSource;
        
        _service = [CBUUID UUIDWithString:@"310a0001-1b95-5091-b0bd-b7a681846399"];
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (CBUUID *)serviceUUID
{
    return _service;
}

- (void)setServiceUUID:(CBUUID *)serviceUUID
{
    if ([_service isEqualTo:serviceUUID]) {
        return;
    }
    
    _service = serviceUUID;
    [_dataSource removeAllMembers];
    [_tableView reloadData];
    [self centralManagerDidUpdateState:_centralManager];
}

- (NSInteger)columnIndexForIdentifier:(NSString *)identifier
{
    NSInteger index = 0;
    for (NSTableColumn *column in _tableView.tableColumns) {
        if ([column.identifier isEqualToString:identifier]) {
            return index;
        }
        ++index;
    }
    @throw [NSException exceptionWithName:@"TableColumnNotFound" reason:@"Table Column Not Found" userInfo:nil];
}

- (void)executorChanged:(FDExecutor *)executor
{
    FDPoolMember *member = [_dataSource memberForExecutor:executor];
    member.executor = executor.hasTasks ? [NSString stringWithFormat:@"%lu", (unsigned long)executor.allTasks.count] : nil;
    NSInteger rowIndex = [_dataSource getMemberIndex:member];
    NSRect rowRect = [_tableView rectOfRow:rowIndex];
    NSInteger columnIndex = [self columnIndexForIdentifier:@"executor"];
    NSRect columnRect = [_tableView rectOfColumn:columnIndex];
    NSRect rect = NSIntersectionRect(rowRect, columnRect);
    [_tableView setNeedsDisplayInRect:rect];
}

- (void)fireflyIce:(FDFireflyIce *)fireflyIce channel:(id<FDFireflyIceChannel>)channel power:(FDFireflyIcePower *)power
{
    FDFireflyIceChannelBLE *channelBLE = fireflyIce.channels[@"BLE"];
    FDPoolMember *member = [_dataSource memberForPeripheral:channelBLE.peripheral];
    
    member.batteryVoltage = [NSString stringWithFormat:@"%0.2f", power.batteryVoltage];
    member.chargeCurrent = [NSString stringWithFormat:@"%0.1f", power.chargeCurrent * 1000];
    member.temperature = [NSString stringWithFormat:@"%0.2f", power.temperature];
    
    [self memberDataHasChanged:member];
}

- (void)helloTaskSuccess:(FDHelloTask *)helloTask
{
    FDFireflyIce *fireflyIce = helloTask.fireflyIce;
    FDFireflyIceChannelBLE *channel = fireflyIce.channels[@"BLE"];
    FDPoolMember *member = [_dataSource memberForPeripheral:channel.peripheral];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    
    FDFireflyIceVersion *version = helloTask.propertyValues[@"version"];
    member.version = [NSString stringWithFormat:@"%d", version.patch];
    
    FDFireflyIceReset *reset = helloTask.propertyValues[@"reset"];
    long age = (long)[[NSDate date] timeIntervalSinceDate:reset.date];
    if (age < 60 * 60 * 24 * 365) {
        member.lastReset = [NSString stringWithFormat:@"%lds ago %@", (long)[[NSDate date] timeIntervalSinceDate:reset.date], [FDFireflyIceReset causeDescription:reset.cause]];
    } else {
        member.lastReset = [FDFireflyIceReset causeDescription:reset.cause];
    }
    
    FDFireflyIcePower *power = helloTask.propertyValues[@"power"];
    member.batteryVoltage = [NSString stringWithFormat:@"%0.2f", power.batteryVoltage];
    member.chargeCurrent = [NSString stringWithFormat:@"%0.1f", power.chargeCurrent * 1000];
    member.temperature = [NSString stringWithFormat:@"%0.2f", power.temperature];
    
    [self memberDataHasChanged:member];
}

- (void)helloTask:(FDHelloTask *)helloTask error:(NSError *)error
{
    NSLog(@"hello task error");
}

- (void)fireflyIce:(FDFireflyIce *)fireflyIce channel:(id<FDFireflyIceChannel>)channel status:(FDFireflyIceChannelStatus)status
{
    if (status == FDFireflyIceChannelStatusOpen) {
        FDHelloTask *helloTask = [FDHelloTask helloTask:fireflyIce channel:channel delegate:self];
        helloTask.setTimeEnabled = NO;
        [helloTask queryProperty:FD_CONTROL_PROPERTY_POWER delegateMethodName:@"fireflyIce:channel:power:"];
        [fireflyIce.executor execute:helloTask];
    }
    FDFireflyIceChannelBLE *channelBLE = fireflyIce.channels[@"BLE"];
    FDPoolMember *member = [_dataSource memberForPeripheral:channelBLE.peripheral];
    [self memberDataHasChanged:member];
}

- (void)applyToAll:(void (^)(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel))block
{
    for (FDPoolMember *member in _dataSource.members) {
        FDFireflyIce *fireflyIce = member.fireflyIce;
        FDFireflyIceChannelBLE *channel = fireflyIce.channels[@"BLE"];
        block(fireflyIce, channel);
    }
}

- (void)applyToSelected:(void (^)(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel))block
{
    NSIndexSet *indexSet = _tableView.selectedRowIndexes;
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        FDPoolMember *member = [_dataSource getMemberAtIndex:index];
        FDFireflyIce *fireflyIce = member.fireflyIce;
        FDFireflyIceChannelBLE *channel = fireflyIce.channels[@"BLE"];
        block(fireflyIce, channel);
    }];
}

- (void)applyToSelectedOpen:(void (^)(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel))block
{
    [self applyToSelected:^(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        if (channel.status == FDFireflyIceChannelStatusOpen) {
            block(fireflyIce, channel);
        }
    }];
}

- (void)executeTaskOnSelectedOpen:(id<FDExecutorTask> (^)(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel))block
{
    [self applyToSelectedOpen:^(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        id<FDExecutorTask> task = block(fireflyIce, channel);
        [fireflyIce.executor execute:task];
    }];
}

- (void)executeBlockOnSelectedOpen:(void (^)(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel))block
{
    [self executeTaskOnSelectedOpen:^id<FDExecutorTask>(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        return [FDFireflyIceSimpleTask simpleTask:fireflyIce channel:channel block:^{
            block(fireflyIce, channel);
        }];
    }];
}

- (void)rescanPool
{
    [self applyToAll:^(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [channel close];
    }];
    [_dataSource removeAllMembers];
    [_tableView reloadData];
}

- (void)openPool
{
    [self applyToSelected:^(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [channel open];
    }];
}

- (void)closePool
{
    [self applyToSelected:^(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [channel close];
    }];
}

- (void)indicatePool
{
    [self executeBlockOnSelectedOpen:^void(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [fireflyIce.coder sendIdentify:channel duration:10.0];
    }];
}

- (void)resetPool
{
    [self executeBlockOnSelectedOpen:^void(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [fireflyIce.coder sendReset:channel type:FD_CONTROL_RESET_SYSTEM_REQUEST];
    }];
}

- (void)refreshPool
{
    [self executeBlockOnSelectedOpen:^void(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [fireflyIce.coder sendGetProperties:channel properties:FD_CONTROL_PROPERTY_POWER];
    }];
}

- (void)setTimePool
{
    [self executeBlockOnSelectedOpen:^void(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [fireflyIce.coder sendSetPropertyTime:channel time:[NSDate date]];
    }];
}

- (void)updatePool:(FDIntelHex *)firmware
{
    [self executeTaskOnSelectedOpen:^id<FDExecutorTask>(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        return [FDFirmwareUpdateTask firmwareUpdateTask:fireflyIce channel:channel intelHex:firmware];
    }];
}

- (void)erasePool
{
    [self executeBlockOnSelectedOpen:^void(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [fireflyIce.coder sendProvision:channel dictionary:[NSDictionary dictionary] options:FD_CONTROL_PROVISION_OPTION_SENSING_ERASE | FD_CONTROL_PROVISION_OPTION_RESET];
    }];
}

- (void)storagePool
{
    [self executeBlockOnSelectedOpen:^void(FDFireflyIce *fireflyIce, FDFireflyIceChannelBLE *channel) {
        [fireflyIce.coder sendSetPropertyMode:channel mode:FD_CONTROL_MODE_STORAGE];
    }];
}

- (void)centralManagerPoweredOn
{
    NSArray *peripherals = [_centralManager retrieveConnectedPeripheralsWithServices:@[_service]];
    for (CBPeripheral *peripheral in peripherals) {
        [self onMainCentralManager:_centralManager didDiscoverPeripheral:peripheral advertisementData:@{CBAdvertisementDataServiceUUIDsKey:@[_service]} RSSI:peripheral.RSSI];
    }
    [_centralManager scanForPeripheralsWithServices:@[_service] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
//    [_centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
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

- (NSString *)nameForPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData
{
    NSString *name = advertisementData[CBAdvertisementDataLocalNameKey];
    if (name == nil) {
        name = @"anonymous";
    }
    NSString *UUIDString = [peripheral.identifier UUIDString];
    return [NSString stringWithFormat:@"%@ %@", name, UUIDString];
}

- (void)memberDataHasChanged:(FDPoolMember *)member
{
    NSInteger rowIndex = [_dataSource getMemberIndex:member];
    [_tableView setNeedsDisplayInRect:[_tableView rectOfRow:rowIndex]];
}

- (void)discovered:(FDPoolMember *)member
{
    [_dataSource addMember:member];
    [_tableView noteNumberOfRowsChanged];
}

- (void)onMainCentralManager:(CBCentralManager *)central
       didDiscoverPeripheral:(CBPeripheral *)peripheral
           advertisementData:(NSDictionary *)advertisementData
                        RSSI:(NSNumber *)RSSI
{
    if (advertisementData.count == 0) {
        // !!! Bug in Mac OS X 10.9.3 (13D38)?  If advertisementData is nil, how can it know the service UUID to get here? -denis
        return;
    }
    
    FDPoolMember *member = [_dataSource memberForPeripheral:peripheral];
    if (member != nil) {
        if (advertisementData != nil) {
            NSMutableDictionary *newAdvertisementData = [NSMutableDictionary dictionaryWithDictionary:member.advertisementData];
            [advertisementData enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
                [newAdvertisementData setObject:value forKey:key];
            }];
            NSDictionary *previousAdvertisementData = member.advertisementData;
            if (![newAdvertisementData isEqualToDictionary:previousAdvertisementData]) {
                member.advertisementData = newAdvertisementData;
                FDFireflyIce *fireflyIce = member.fireflyIce;
                fireflyIce.name = [self nameForPeripheral:peripheral advertisementData:newAdvertisementData];
                [self memberDataHasChanged:member];
            }
        }
        return;
    }
    
    FDFireflyIce *fireflyIce = [[FDFireflyIce alloc] init];
    fireflyIce.name = [self nameForPeripheral:peripheral advertisementData:advertisementData];
    [fireflyIce.observable addObserver:self];
    [fireflyIce.executor.observable addObserver:self];
    FDFireflyIceChannelBLE *channel = [[FDFireflyIceChannelBLE alloc] initWithCentralManager:central withPeripheral:peripheral withServiceUUID:_service];
    channel.RSSI = [FDFireflyIceChannelBLERSSI RSSI:[RSSI floatValue]];
    [fireflyIce addChannel:channel type:@"BLE"];
    member = [[FDPoolMember alloc] init];
    member.advertisementData = advertisementData;
    member.fireflyIce = fireflyIce;
    
    [self discovered:member];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    __weak FDPoolManager *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf onMainCentralManager:central didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
    });
}

- (void)onMainCentralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    FDPoolMember *member = [_dataSource memberForPeripheral:peripheral];
    FDFireflyIce *fireflyIce = member.fireflyIce;
    FDFireflyIceChannelBLE *channel = fireflyIce.channels[@"BLE"];
    [channel didConnectPeripheral];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    __weak FDPoolManager *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf onMainCentralManager:central didConnectPeripheral:peripheral];
    });
}

- (void)onMainCentralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    FDPoolMember *member = [_dataSource memberForPeripheral:peripheral];
    FDFireflyIce *fireflyIce = member.fireflyIce;
    FDFireflyIceChannelBLE *channel = fireflyIce.channels[@"BLE"];
    [channel didDisconnectPeripheralError:error];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    __weak FDPoolManager *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf onMainCentralManager:central didDisconnectPeripheral:peripheral error:error];
    });
}

@end
