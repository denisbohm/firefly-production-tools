//
//  FDBarCodeScanner.h
//  FireflyProduction
//
//  Created by Denis Bohm on 12/15/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <FireflyDevice/FDUSBHIDMonitor.h>

@class FDBarCodeScanner;

@protocol FDBarCodeScannerDelegate <NSObject>

- (void)barCodeScanner:(FDBarCodeScanner *)barCodeScanner scan:(NSString *)scan;

@end

@interface FDBarCodeScanner : NSObject

- (id)initWithDevice:(FDUSBHIDDevice *)hidDevice;

@property FDUSBHIDDevice *hidDevice;
@property id<FDBarCodeScannerDelegate> delegate;

@end
