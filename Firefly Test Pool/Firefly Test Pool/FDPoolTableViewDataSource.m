//
//  FDPoolTableViewDataSource.m
//  Firefly Test Pool
//
//  Created by Denis Bohm on 4/18/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDPoolTableViewDataSource.h"

#import "FDPoolMember.h"

#import <FireflyDevice/FDFireflyIce.h>
#import <FireflyDevice/FDFireflyIceChannelBLE.h>

@interface FDPoolTableViewDataSource ()

@end

@implementation FDPoolTableViewDataSource

- (id)init
{
    if (self = [super init]) {
        _members = [NSMutableArray array];
    }
    return self;
}

- (FDPoolMember *)memberForPeripheral:(CBPeripheral *)peripheral
{
    for (FDPoolMember *member in _members) {
        FDFireflyIce *fireflyIce = member.fireflyIce;
        FDFireflyIceChannelBLE *channel = fireflyIce.channels[@"BLE"];
        if (channel.peripheral == peripheral) {
            return member;
        }
    }
    return nil;
}

- (FDPoolMember *)memberForExecutor:(FDExecutor *)executor
{
    for (FDPoolMember *member in _members) {
        FDFireflyIce *fireflyIce = member.fireflyIce;
        if (fireflyIce.executor == executor) {
            return member;
        }
    }
    return nil;
}

- (NSInteger)addMember:(FDPoolMember *)member
{
    [_members addObject:member];
    return _members.count - 1;
}

- (NSInteger)getMemberIndex:(FDPoolMember *)member
{
    return [_members indexOfObject:member];
}

- (FDPoolMember *)getMemberAtIndex:(NSInteger)index
{
    return _members[index];
}

- (void)removeAllMembers
{
    [_members removeAllObjects];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _members.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    FDPoolMember *member = [_members objectAtIndex:rowIndex];
    NSString *column = tableColumn.identifier;
    if ([column isEqualToString:@"name"]) {
        return member.fireflyIce.name;
    } else
    if ([column isEqualToString:@"connection"]) {
        FDFireflyIceChannelBLE *channel = member.fireflyIce.channels[@"BLE"];
        switch (channel.status) {
            case FDFireflyIceChannelStatusClosed:
                return @"closed";
            case FDFireflyIceChannelStatusOpening:
                return @"opening";
            case FDFireflyIceChannelStatusOpen:
                return @"open";
        }
    } else
    if ([column isEqualToString:@"executor"]) {
        return member.executor;
    } else
    if ([column isEqualToString:@"version"]) {
        return member.version;
    } else
    if ([column isEqualToString:@"lastReset"]) {
        return member.lastReset;
    } else
    if ([column isEqualToString:@"chargeCurrent"]) {
        return member.chargeCurrent;
    }
    if ([column isEqualToString:@"batteryVoltage"]) {
        return member.batteryVoltage;
    }
    if ([column isEqualToString:@"temperature"]) {
        return member.temperature;
    }
    return nil;
}

@end
