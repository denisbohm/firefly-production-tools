//
//  FDI2C.m
//  FireflyProduction
//
//  Created by Denis Bohm on 12/28/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDI2C.h"

#import <ARMSerialWireDebug/ARMSerialWireDebug.h>

// This interface is for the C232HM-DDHSL-0 USB device from FTDI (vid 0403 / pid 6014).
//
// Wires (Note that pins 2 & 3 need to be shorted externally):
// 1 - red - VCC - 3.3 V
// 2 - orange - SCL (TCK) (ADBUS0)
// 3 - yellow - SDA (TDI) (ADBUS1)
// 4 - green - SDA (TDO) (ADBUS2)
// 5 - brown - TMS (ADBUS3)
// 6 - gray - GPIOL0 (ADBUS4)
// 7 - purple - GPIOL1 (ADBUS5)
// 8 - white - GPIOL2 (ADBUS6)
// 9 - blue - GPIOL3 (ADBUS7)
// 10 - black - GND
//
// LEDs:
// ACBUS6 - red // gpio bit 13
// ACBUS8 - green
//
// Power Control to VCC wire:
// ACBUS9

// Apple loads a driver and it takes exclusive access.  So need to unload it using the following command. -denis
// sudo kextunload -bundle-id com.apple.driver.AppleUSBFTDI
// -or-
// The vid / pid in the internal EEPROM in the cable can be re-programmed over USB using the utility program FT_PROG.

@interface FDI2C ()

@property UInt16 gpioInputs;
@property UInt16 gpioOutputs;
@property UInt16 gpioDirections;

@property NSUInteger redLEDBit;

@end

@implementation FDI2C

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        _clockStretchTimeout = 1.0;
    }
    return self;
}

- (void)initialize
{
    _gpioDirections = 0b0000000000000000; // all inputs
    _gpioOutputs    = 0b0000000000000000;
    
    _redLEDBit = 14;
    _gpioDirections |= 1 << _redLEDBit; // output
    _gpioOutputs |= 1 << _redLEDBit; // high == LED OFF
    
    @try {
        [_serialEngine read];
    } @catch (NSException *e) {
        FDLog(@"unexpected exception: %@", e);
    }
    
    [_serialEngine setLoopback:false];
    [_serialEngine setClockDivisor:5];
    [_serialEngine write];
    
    [_serialEngine setLatencyTimer:2];
    [_serialEngine setMPSEEBitMode];
    [_serialEngine reset];
    
    [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    [_serialEngine sendImmediate];
    [_serialEngine write];
    
    [self getGpios];
}

- (void)getGpios
{
    [_serialEngine getLowByte]; // ADBus 7-0
    [_serialEngine getHighByte]; // ACBus 7-0
    [_serialEngine sendImmediate];
    [_serialEngine write];
    NSData *data = [_serialEngine read:2];
    UInt8 *bytes = (UInt8 *)data.bytes;
    _gpioInputs = (bytes[1] << 8) | bytes[0];
}

- (void)setGpioBit:(NSUInteger)bit value:(BOOL)value
{
    UInt16 mask = 1 << bit;
    UInt16 outputs = _gpioOutputs;
    if (value) {
        outputs |= mask;
    } else {
        outputs &= ~mask;
    }
    if (outputs == _gpioOutputs) {
        return;
    }
    _gpioOutputs = outputs;
    [self sendGpios:mask];
}

- (void)sendGpios:(uint16_t)mask
{
    if (mask & 0x00ff) {
        [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    } else {
        [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    }
    [self.serialEngine write];
}

- (void)setRedLED:(BOOL)value
{
    [self setGpioBit:_redLEDBit value:!value];
}

- (void)setTristate:(NSUInteger)bit value:(BOOL)value
{
    if (value) {
        [self configureGpiosAsInputs:1 << bit];
    } else {
        [self configureGpiosAsOutputs:1 << bit values:0x0000];
    }
}

- (BOOL)getTristate:(NSUInteger)bit
{
    [self getGpios];
    return (_gpioInputs >> bit) & 0x0001;
}

- (void)checkCancel
{
    if ([NSThread currentThread].isCancelled) {
        @throw [NSException exceptionWithName:@"Cancelled" reason:@"Cancelled" userInfo:nil];
    }
}

// Bit Bang I2C

#define WRITE 0x0
#define READ 0x1

#define READ_SDA() [self getGpioInput:_sdaBit]
#define SET_SDA_OUT() [self configureGpiosAsOutputs:1 << _sdaBit values:0x0000]
#define SET_SDA_IN() [self configureGpiosAsInputs:1 << _sdaBit]
#define SET_SDA(v) if (v) SET_SDA_IN(); else SET_SDA_OUT()

#define READ_SCL() [self getGpioInput:_sclBit]
#define TOGGLE_SCL()
#define SET_SCL_OUT() [self configureGpiosAsOutputs:1 << _sclBit values:0x0000]
#define SET_SCL_IN() [self configureGpiosAsInputs:1 << _sclBit]
#define SET_SCL(v) [self setScl:v]

#define SCL_DELAY() [NSThread sleepForTimeInterval:0.0001]
#define SCL_SDA_DELAY() [NSThread sleepForTimeInterval:0.0001]

- (BOOL)getGpioInput:(NSUInteger)bit
{
    [self getGpios];
    return (_gpioInputs >> bit) & 0x0001;
}

- (void)configureGpiosAsOutputs:(uint16_t)mask values:(uint16_t)values
{
    _gpioDirections |= mask;
    _gpioOutputs = (_gpioOutputs & ~mask) | values;
    [self sendGpios:mask];
}

- (void)configureGpiosAsInputs:(uint16_t)mask
{
    _gpioDirections &= ~mask;
    [self sendGpios:mask];
}

- (BOOL)clearBus
{
    SET_SDA(1);
    SET_SCL(1);
    SCL_DELAY();
    
    if (READ_SDA() && READ_SCL()) {
        return YES;
    }
    
    if (READ_SCL()) {
        // Clock max 18 pulses worst case scenario(9 for master to send the rest of command and 9 for slave to respond) to SCL line and wait for SDA come high
        for (int i = 0; i < 18; ++i) {
            SET_SCL(0);
            SCL_DELAY();
            SET_SCL(1);
            SCL_DELAY();
            
            if (READ_SDA()) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)sendStartCondition
{
    NSLog(@"i2c start");

    SET_SDA(0);
    SCL_DELAY();
    
    SET_SCL(0);
    SCL_DELAY();
}

- (void)setScl:(BOOL)value
{
    if (value) {
        SET_SCL_IN();
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:_clockStretchTimeout];
        while (!READ_SCL()) {
            if ([[NSDate date] isGreaterThanOrEqualTo:deadline]) {
                @throw [NSException exceptionWithName:@"ClocKStretchTimeout" reason:@"clock stretch timeout" userInfo:nil];
            }
        }
    } else {
        SET_SCL_OUT();
    }
}

- (BOOL)sendSlaveAddress:(uint8_t)read
{
    return [self i2cWriteByte:_address | read];
}

- (BOOL)transmit:(uint8_t *)bytes length:(NSUInteger)length
{
    [self checkCancel];
    
    [self sendStartCondition];
    if (![self sendSlaveAddress:WRITE]) {
        return NO;
    }
    
    BOOL ack = NO;
    for (int index = 0; index < length; index++) {
        ack = [self i2cWriteByte:bytes[index]];
        if (!ack) {
            break;
        }
    }
    //put stop here
    SET_SCL(1);
    SCL_SDA_DELAY();
    SET_SDA(1);
    NSLog(@"i2c stop");
    return ack;
}

- (BOOL)i2cWriteByte:(uint8_t)byte
{
    NSLog(@"i2c write byte %02x", byte);
    
    for (int bit = 0; bit < 8; bit++) {
        SET_SDA((byte & 0x80) != 0);
        SET_SCL(1);
        SCL_DELAY();
        SET_SCL(0);
        byte <<= 1;
        SCL_DELAY();
    }
    //release SDA
    SET_SDA_IN();
    SET_SCL(1); //goes high for the 9th clock
    //Check for acknowledgment
    if (READ_SDA()) {
        NSLog(@"i2c write byte NACK");
        return NO;
    }
    SCL_DELAY();
    SET_SCL(0); //end of byte with acknowledgment.
    //take SDA
    SET_SDA_OUT();
    SCL_DELAY();
    NSLog(@"i2c write byte ack");
    return YES;
}

- (BOOL)receive:(uint8_t *)bytes length:(NSUInteger)length
{
    [self checkCancel];
    
    [self sendStartCondition];
    if (![self sendSlaveAddress:READ]) {
        return NO;
    }
    for (NSUInteger index = 0; index < length; index++) {
        [self i2cReadByte:bytes length:length index:index];
    }
    //put stop here
    SET_SCL(1);
    SCL_SDA_DELAY();
    SET_SDA(1);
    NSLog(@"i2c stop");
    return YES;
}

- (void)i2cReadByte:(uint8_t *)rcvdata length:(NSUInteger)length index:(NSUInteger)index
{
    unsigned char byte = 0;
    //release SDA
    SET_SDA_IN();
    for (int bit = 0; bit < 8; bit++) {
        SET_SCL(1);
        if (READ_SDA()) {
            byte |= (1 << (7 - bit));
        }
        SCL_DELAY();
        SET_SCL(0);
        SCL_DELAY();
    }
    NSLog(@"i2c read byte %02x", byte);
    
    rcvdata[index] = byte;
    //take SDA
    SET_SDA_OUT();
    if (index < (length - 1)) {
        SET_SDA(0);
        SET_SCL(1); //goes high for the 9th clock
        SCL_DELAY();
        SET_SCL(0); //end of byte with acknowledgment.
        //release SDA
        SET_SDA(1);
        SCL_DELAY();
    }
    else //send NACK on the last byte
    {
        SET_SDA(1);
        SET_SCL(1); //goes high for the 9th clock
        SCL_DELAY();
        SET_SCL(0); //end of byte with acknowledgment.
        //release SDA
        SCL_DELAY();
    }
}

@end
