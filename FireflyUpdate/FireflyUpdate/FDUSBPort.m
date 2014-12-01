//
//  FDUSBPort.m
//  FireflyUpdate
//
//  Created by Denis Bohm on 10/8/14.
//  Copyright (c) 2014 Firefly Design LLC. All rights reserved.
//

#import "FDUSBPort.h"

@interface FDUSBPort () <FDFireflyIceObserver, FDHelloTaskDelegate, FDFirmwareUpdateTaskDelegate>

@property BOOL wasFirmwareUpToDate;
@property NSColor *textColor;

@end

@implementation FDUSBPort

- (void)setTextField:(NSTextField *)textField faded:(BOOL)faded
{
    [textField setTextColor:faded ? [NSColor grayColor] : [NSColor blackColor]];
}

- (void)showPluggedIn
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _hardwareId.stringValue = @"";
        _progressIndicator.doubleValue = 0.0;
        _status.stringValue = @"Device plugged in...";
        _status.hidden = NO;
        [self setTextField:_status faded:NO];
    });
}

- (void)showHardwareId:(NSData *)unique
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _hardwareId.stringValue = [FDHardwareId hardwareId:unique];
        _hardwareId.hidden = NO;
        [self setTextField:_hardwareId faded:NO];
    });
}

- (void)showStatus:(NSString *)status
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _status.stringValue = status;
    });
}

- (void)showProgress:(double)progress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _progressIndicator.doubleValue = progress * 100;
        _progressIndicator.hidden = NO;
    });
}

- (void)fadeAway
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setTextField:_hardwareId faded:YES];
        _progressIndicator.hidden = YES;
        [self setTextField:_status faded:YES];
        if ([_status.stringValue hasPrefix:@"Putting"]) {
            _status.stringValue = @"Firmware is up to date.  Device has been put into storage mode.";
        }
    });
}

- (void)start:(FDUSBHIDDevice *)usbHidDevice
{
    [self showPluggedIn];
    
    _fireflyIce = [[FDFireflyIce alloc] init];
    FDFireflyIceChannelUSB *channel = [[FDFireflyIceChannelUSB alloc] initWithDevice:usbHidDevice];
    [_fireflyIce addChannel:channel type:@"USB"];
    
    [_fireflyIce.observable addObserver:self];
    
    [channel open];
}

- (void)stop
{
    id<FDFireflyIceChannel> channel = _fireflyIce.channels[@"USB"];
    [_fireflyIce removeChannel:@"USB"];
    [channel close];
    _fireflyIce = nil;
    _usbHidDevice = nil;

    [self fadeAway];
}

- (void)fireflyIce:(FDFireflyIce *)fireflyIce channel:(id<FDFireflyIceChannel>)channel status:(FDFireflyIceChannelStatus)status
{
    switch (status) {
        case FDFireflyIceChannelStatusOpening:
            break;
        case FDFireflyIceChannelStatusOpen:
            [fireflyIce.executor execute:[FDHelloTask helloTask:fireflyIce channel:channel delegate:self]];
            break;
        case FDFireflyIceChannelStatusClosed:
            break;
    }
}

- (void)helloTaskSuccess:(FDHelloTask *)helloTask
{
    [self showHardwareId:_fireflyIce.hardwareId.unique];

    FDFireflyIce *fireflyIce = helloTask.fireflyIce;
    id<FDFireflyIceChannel> channel = helloTask.channel;
    FDFirmwareUpdateTask *task = [FDFirmwareUpdateTask firmwareUpdateTask:fireflyIce channel:channel intelHex:_firmware];
    task.useArea = YES;
    task.area = FD_HAL_SYSTEM_AREA_APPLICATION;
    task.downgrade = YES;
    task.commit = YES;
    task.reset = YES;
    task.delegate = self;
    [fireflyIce.executor execute:task];
}

- (void)helloTask:(FDHelloTask *)helloTask error:(NSError *)error
{
    id<FDFireflyIceChannel> channel = helloTask.channel;
    [channel close];
}

- (void)firmwareUpdateTask:(FDFirmwareUpdateTask *)task check:(BOOL)isFirmwareUpToDate
{
    _wasFirmwareUpToDate = isFirmwareUpToDate;
    if (!isFirmwareUpToDate) {
        [self showStatus:@"Updating firmware..."];
    }
}

- (void)firmwareUpdateTask:(FDFirmwareUpdateTask *)task progress:(float)progress
{
    [self showProgress:progress];
}

- (void)firmwareUpdateTask:(FDFirmwareUpdateTask *)task complete:(BOOL)isFirmwareUpToDate
{
    if (_wasFirmwareUpToDate) {
        [self showStatus:@"Putting device into storage mode..."];
        FDFireflyIce *fireflyIce = _fireflyIce;
        id<FDFireflyIceChannel> channel = fireflyIce.channels[@"USB"];
        FDFireflyIceSimpleTask *storageModeTask = [FDFireflyIceSimpleTask simpleTask:_fireflyIce channel:channel block:^() {
            [fireflyIce.coder sendProvision:channel dictionary:nil options:FD_CONTROL_PROVISION_OPTION_SENSING_ERASE];
            [fireflyIce.coder sendSetPropertyMode:channel mode:FD_CONTROL_MODE_STORAGE];
        }];
        storageModeTask.priority = -1000;
        [_fireflyIce.executor execute:storageModeTask];
    } else {
        [self showStatus:isFirmwareUpToDate ? @"Firmware has been updated (restarting)..." : @"Firmware update failed!"];
    }
}

@end
