//
//  FDBarCodeScanner.m
//  FireflyProduction
//
//  Created by Denis Bohm on 12/15/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDBarCodeScanner.h"

@interface FDBarCodeScanner () <FDUSBHIDDeviceDelegate>

@property NSMutableString *scan;

@end

@implementation FDBarCodeScanner

- (id)initWithDevice:(FDUSBHIDDevice *)hidDevice
{
    if (self = [super init]) {
        _hidDevice = hidDevice;
        _hidDevice.delegate = self;
        _scan = [NSMutableString string];
    }
    return self;
}

static char scanCodeToUpperCaseChar[256] = {
    0, 0, 0, 0,
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '\r', 0x1b, '\b', '\t', ' ', '_', '+', '{', '}', '|', 0, ':', '"', '~', '<', '>', '?',
};

static char scanCodeToLowerCaseChar[256] = {
    0, 0, 0, 0,
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '\r', 0x1b, '\b', '\t', ' ', '-', '=', '[', ']', '\\', 0, ';', '\'', '`', ',', '.', '/',
};

- (void)usbHidDevice:(FDUSBHIDDevice *)device inputReport:(NSData *)data
{
    if (data.length != 8) {
        return;
    }
    uint8_t *bytes = (uint8_t *)data.bytes;
    uint8_t scanCode = bytes[2];
    if (scanCode == 0x00) {
        return;
    }
    uint8_t modifiers = bytes[0];
    bool shift = (modifiers & 0x22) != 0;
    char c = shift ? scanCodeToUpperCaseChar[scanCode] : scanCodeToLowerCaseChar[scanCode];
    if (c == 0) {
        return;
    }
    
    if (c == '\r') {
        if (_delegate != nil) {
            NSString *scan = [NSString stringWithString:_scan];
            [_scan setString:@""];
            [_delegate barCodeScanner:self scan:scan];
        }
    } else {
        [_scan appendFormat:@"%c", c];
    }
}

@end
