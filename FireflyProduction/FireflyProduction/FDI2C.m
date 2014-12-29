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
// ACBUS6 - red
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

@end

@implementation FDI2C

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        
        _gpioDirections = 0b0000000000000000; // all inputs
        _gpioOutputs    = 0b0000000000000000;
    }
    return self;
}

- (void)initialize
{
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
    [_serialEngine getLowByte];
    [_serialEngine getHighByte];
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
    if (mask & 0x00ff) {
        [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    } else {
        [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    }
}

#if 0
typedef uint8_t BYTE;
typedef uint32_t DWORD;
typedef uint32_t FT_STATUS;
typedef uint32_t FT_HANDLE;

const BYTE MSB_FALLING_EDGE_CLOCK_BYTE_IN = '\x24';
const BYTE MSB_FALLING_EDGE_CLOCK_BYTE_OUT = '\x11';
const BYTE MSB_RISING_EDGE_CLOCK_BIT_IN = '\x22';
FT_STATUS ftStatus;
FT_HANDLE ftHandle;
BYTE OutputBuffer[1024];
BYTE InputBuffer[1024];
DWORD dwClockDivisor = 0x0095;
DWORD dwNumBytesToSend = 0;
DWORD dwNumBytesSent = 0, dwNumBytesRead = 0, dwNumInputBuffer = 0;
DWORD dwCount;
//Status defined in D2XX to indicate operation result
//Handle of FT2232H device port
//Buffer to hold MPSSE commands and data to be sent to FT2232H
//Buffer to hold Data bytes to be read from FT2232H
//Value of clock divisor, SCL Frequency = 60/((1+0x0095)*2) (MHz) = 200khz //Index of output buffer
//////////////////////////////////////////////////////////////////////////////////////
// Below function will setup the START condition for I2C bus communication. First, set SDA, SCL high and ensure hold time
// requirement by device is met. Second, set SDA low, SCL high and ensure setup time requirement met. Finally, set SDA, SCL low ////////////////////////////////////////////////////////////////////////////////////////
void HighSpeedSetI2CStart(void)
{
    for(dwCount=0; dwCount < 4; dwCount++) // Repeat commands to ensure the minimum period of the start hold time ie 600ns is achieved
    {
        OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output
    OutputBuffer[dwNumBytesToSend++] = '\x03'; //Set SDA, SCL high, WP disabled by SK, DO at bit „1‟, GPIOL0 at bit „0‟
    OutputBuffer[dwNumBytesToSend++] = '\x13'; //Set SK,DO,GPIOL0 pins as output with bit „1‟, other pins as input with bit „0‟
}
for(dwCount=0; dwCount < 4; dwCount++) // Repeat commands to ensure the minimum period of the start setup time ie 600ns is achieved
{
OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output OutputBuffer[dwNumBytesToSend++] = '\x01'; //Set SDA low, SCL high, WP disabled by SK at bit „1‟, DO, GPIOL0 at bit „0‟ OutputBuffer[dwNumBytesToSend++] = '\x13'; //Set SK,DO,GPIOL0 pins as output with bit „1‟, other pins as input with bit „0‟
}
OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output OutputBuffer[dwNumBytesToSend++] = '\x00'; //Set SDA, SCL low, WP disabled by SK, DO, GPIOL0 at bit „0‟ OutputBuffer[dwNumBytesToSend++] = '\x13'; //Set SK,DO,GPIOL0 pins as output with bit „1‟, other pins as input with bit „0‟
}
//////////////////////////////////////////////////////////////////////////////////////
// Below function will setup the STOP condition for I2C bus communication. First, set SDA low, SCL high and ensure setup time
// requirement by device is met. Second, set SDA, SCL high and ensure hold time requirement met. Finally, set SDA, SCL as input // to tristate the I2C bus.
////////////////////////////////////////////////////////////////////////////////////////
void HighSpeedSetI2CStop(void)
{
    DWORD dwCount;
    for(dwCount=0; dwCount<4; dwCount++) // Repeat commands to ensure the minimum period of the stop setup time ie 600ns is achieved
    {
        OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output
    OutputBuffer[dwNumBytesToSend++] = '\x01'; //Set SDA low, SCL high, WP disabled by SK at bit „1‟, DO, GPIOL0 at bit „0‟
    OutputBuffer[dwNumBytesToSend++] = '\x13'; //Set SK,DO,GPIOL0 pins as output with bit „1‟, other pins as input with bit „0‟
}
for(dwCount=0; dwCount<4; dwCount++) // Repeat commands to ensure the minimum period of the stop hold time ie 600ns is achieved
{
OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output
OutputBuffer[dwNumBytesToSend++] = '\x03'; //Set SDA, SCL high, WP disabled by SK, DO at bit „1‟, GPIOL0 at bit „0‟
OutputBuffer[dwNumBytesToSend++] = '\x13'; //Set SK,DO,GPIOL0 pins as output with bit „1‟, other pins as input with bit „0‟
}
//Tristate the SCL, SDA pins
OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output
OutputBuffer[dwNumBytesToSend++] = '\x00'; //Set WP disabled by GPIOL0 at bit „0‟
OutputBuffer[dwNumBytesToSend++] = '\x10'; //Set GPIOL0 pins as output with bit „1‟, SK, DO and other pins as input with bit „0‟
}
//////////////////////////////////////////////////////////////////////////////////////
// Below function will send a data byte to I2C-bus EEPROM 24LC256, then check if the ACK bit sent from 24LC256 device can be received. // Return true if data is successfully sent and ACK bit is received. Return false if error during sending data or ACK bit can‟t be received //////////////////////////////////////////////////////////////////////////////////////
BOOL SendByteAndCheckACK(BYTE dwDataSend)
{
    FT_STATUS ftStatus = FT_OK;
    OutputBuffer[dwNumBytesToSend++] = MSB_FALLING_EDGE_CLOCK_BYTE_OUT; //Clock data byte out on –ve Clock Edge MSB first
    ￼ftStatus |= FT_SetChars(ftHandle, false, 0, false, 0);
    ftStatus |= FT_SetTimeouts(ftHandle, 0, 5000);
    ftStatus |= FT_SetLatencyTimer(ftHandle, 16);
    ftStatus |= FT_SetBitMode(ftHandle, 0x0, 0x00);
    ftStatus |= FT_SetBitMode(ftHandle, 0x0, 0x02);
    //Disable event and error characters
    //Sets the read and write timeouts in milliseconds for the FT2232H //Set the latency timer
    //Reset controller
    //Enable MPSSE mode
    if (ftStatus != FT_OK)
    { /*Error on initialize MPSEE of FT2232H*/ }
    Sleep(50); // Wait for all the USB stuff to complete and work
    ￼OutputBuffer[dwNumBytesToSend++] = '\x00';
    OutputBuffer[dwNumBytesToSend++] = '\x00';
    OutputBuffer[dwNumBytesToSend++] = dwDataSend;
    //Get Acknowledge bit from EEPROM
    OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output
    OutputBuffer[dwNumBytesToSend++] = '\x00'; //Set SCL low, WP disabled by SK, GPIOL0 at bit „0‟ OutputBuffer[dwNumBytesToSend++] = '\x11'; //Set SK, GPIOL0 pins as output with bit „1‟, DO and other pins as input with bit „0‟
    OutputBuffer[dwNumBytesToSend++] = MSB_RISING_EDGE_CLOCK_BIT_IN; //Command to scan in ACK bit , -ve clock Edge MSB first
    OutputBuffer[dwNumBytesToSend++] = '\x0'; //Length of 0x0 means to scan in 1 bit
    OutputBuffer[dwNumBytesToSend++] = '\x87'; //Send answer back immediate command
    ftStatus = FT_Write(ftHandle, OutputBuffer, dwNumBytesToSend, &dwNumBytesSent); //Send off the commands dwNumBytesToSend = 0; //Clear output buffer
    //Check if ACK bit received, may need to read more times to get ACK bit or fail if timeout
    ftStatus = FT_Read(ftHandle, InputBuffer, 1, &dwNumBytesRead); //Read one byte from device receive buffer
    if ((ftStatus != FT_OK) || (dwNumBytesRead == 0))
    { return FALSE; /*Error, can't get the ACK bit from EEPROM */ }
    else
        if (((InputBuffer[0] & BYTE('\x1')) != BYTE('\x0')) ) //Check ACK bit 0 on data byte read out
        { return FALSE; /*Error, can't get the ACK bit from EEPROM */ } OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output OutputBuffer[dwNumBytesToSend++] = '\x02'; //Set SDA high, SCL low, WP disabled by SK at bit '0', DO, GPIOL0 at bit '1' OutputBuffer[dwNumBytesToSend++] = '\x13'; //Set SK,DO,GPIOL0 pins as output with bit „1‟, other pins as input with bit „0‟ return TRUE;
}

void Initialize(void)
{
    ////////////////////////////////////////////////////////////////////
    //Configure the MPSSE settings for I2C communication with 24LC256 //////////////////////////////////////////////////////////////////
    OutputBuffer[dwNumBytesToSend++] = '\x8A'; //Ensure disable clock divide by 5 for 60Mhz master clock OutputBuffer[dwNumBytesToSend++] = '\x97'; //Ensure turn off adaptive clocking
    OutputBuffer[dwNumBytesToSend++] = '\x8D'; //Enable 3 phase data clock, used by I2C to allow data on both clock edges ftStatus = FT_Write(ftHandle, OutputBuffer, dwNumBytesToSend, &dwNumBytesSent); // Send off the commands
    ￼DWORD dwNumBytesToSend = 0;
    OutputBuffer[dwNumBytesToSend++] = '\x80';
    OutputBuffer[dwNumBytesToSend++] = '\x03';
    OutputBuffer[dwNumBytesToSend++] = '\x13';
    // The SK clock frequency can be worked out by below algorithm with divide by 5 set as off
    // SK frequency = 60MHz /((1 + [(1 +0xValueH*256) OR 0xValueL])*2)
    OutputBuffer[dwNumBytesToSend++] = '\x86'; //Command to set clock divisor OutputBuffer[dwNumBytesToSend++] = dwClockDivisor & '\xFF'; //Set 0xValueL of clock divisor OutputBuffer[dwNumBytesToSend++] = (dwClockDivisor >> 8) & '\xFF'; //Set 0xValueH of clock divisor ftStatus = FT_Write(ftHandle, OutputBuffer, dwNumBytesToSend, &dwNumBytesSent); // Send off the commands
    //Clear output buffer
    //Command to set directions of lower 8 pins and force value on bits set as output //Set SDA, SCL high, WP disabled by SK, DO at bit „1‟, GPIOL0 at bit „0‟
    //Set SK,DO,GPIOL0 pins as output with bit ‟, other pins as input with bit „‟
    dwNumBytesToSend = 0;
    Sleep(20);
    //Turn off loop back in case
    OutputBuffer[dwNumBytesToSend++] = '\x85';
    ftStatus = FT_Write(ftHandle, OutputBuffer, dwNumBytesToSend, &dwNumBytesSent); // Send off the commands dwNumBytesToSend = 0; //Clear output buffer
    Sleep(30);
    //Delay for a while
}

void Write(void)
{
    BOOL bSucceed = TRUE;
    BYTE ByteAddressHigh = 0x00; BYTE ByteAddressLow = 0x80; BYTE ByteDataToBeSend = 0x5A;
    HighSpeedSetI2CStart();
    bSucceed = SendByteAndCheckACK(0xAE);
    //Set program address is 0x0080 as example //Set data byte to be programmed as example
    //Set START condition for I2C communication
    //Set control byte and check ACK bit. bit 4-7 of control byte is control code, // bit 1-3 of „111‟ as block select bits, bit 0 of „0‟represent Write operation
    bSucceed = SendByteAndCheckACK(ByteAddressHigh); //Send high address byte and check if ACK bit is received
    bSucceed = SendByteAndCheckACK(ByteAddressLow); //Send low address byte and check if ACK bit is received
    bSucceed = SendByteAndCheckACK(ByteDataToBeSend); //Send data byte and check if ACK bit is received
    HighSpeedSetI2CStop(); //Set STOP condition for I2C communication //Send off the commands
    ftStatus = FT_Write(ftHandle, OutputBuffer, dwNumBytesToSend, &dwNumBytesSent);
    dwNumBytesToSend = 0; Sleep(50);
    //Clear output buffer
    //Delay for a while to ensure EEPROM program is completed
}

void Read(void)
{
    BOOL bSucceed = TRUE;
    BYTE ByteAddressHigh = 0x00;
    BYTE ByteAddressLow = 0x80; //Set read address is 0x0080 as example BYTE ByteDataRead; //Data to be read from EEPROM
    //Purge USB receive buffer first before read operation
    ftStatus = FT_GetQueueStatus(ftHandle, &dwNumInputBuffer); // Get the number of bytes in the device receive buffer if ((ftStatus == FT_OK) && (dwNumInputBuffer > 0))
    FT_Read(ftHandle, &InputBuffer, dwNumInputBuffer, &dwNumBytesRead); //Read out all the data from receive buffer
    HighSpeedSetI2CStart(); //Set START condition for I2C communication
    bSucceed = SendByteAndCheckACK(0xAE); //Set control byte and check ACK bit. bit 4-7 of control byte is control code,
    // bit 1-3 of „111‟ as block select bits, bit 0 of „0‟represent Write operation bSucceed = SendByteAndCheckACK(ByteAddressHigh); //Send high address byte and check if ACK bit is received
    bSucceed = SendByteAndCheckACK(ByteAddressLow); //Send low address byte and check if ACK bit is received
    ￼￼HighSpeedSetI2CStart();
    bSucceed = SendByteAndCheckACK(0xAF); //Set control byte and check ACK bit.  bit 4-7 as 1010 of control byte is control code
    // bit 1-3 of 111 as block select bits, bit 0 as 1 represent Read operation
    //////////////////////////////////////////////////////////
    // Read the data from 24LC256 with no ACK bit check
    //////////////////////////////////////////////////////////
    OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output
    OutputBuffer[dwNumBytesToSend++] = '\x00'; //Set SCL low, WP disabled by SK, GPIOL0 at bit `'
    OutputBuffer[dwNumBytesToSend++] = '\x11'; //Set SK, CPIOL0 pins as output with bit '', D0 and other pins as input with `'
    OutputBuffer[dwNumBytesToSend++] = MSB_FALLING_EDGE_CLOCK_BYTE_IN; //Command to clock data byte in on –ve Clock Edge MSB first OutputBuffer[dwNumBytesToSend++] = '\x00';
    OutputBuffer[dwNumBytesToSend++] = '\x00'; //Data length of 0x0000 means 1 byte data to clock in OutputBuffer[dwNumBytesToSend++] = MSB_RISING_EDGE_CLOCK_BIT_IN; //Command to scan in acknowledge bit , -ve clock Edge MSB first OutputBuffer[dwNumBytesToSend++] = '\x0'; //Length of 0 means to scan in 1 bit
    OutputBuffer[dwNumBytesToSend++] = '\x87'; //Send answer back immediate command
    ftStatus = FT_Write(ftHandle, OutputBuffer, dwNumBytesToSend, &dwNumBytesSent); //Send off the commands dwNumBytesToSend = 0; //Clear output buffer
    //Read two bytes from device receive buffer, first byte is data read from EEPROM, second byte is ACK bit
    ftStatus = FT_Read(ftHandle, InputBuffer, 2, &dwNumBytesRead);
    ByteDataRead = InputBuffer[0]; //Return the data read from EEPROM
    OutputBuffer[dwNumBytesToSend++] = '\x80'; //Command to set directions of lower 8 pins and force value on bits set as output
    OutputBuffer[dwNumBytesToSend++] = '\x02'; //Set SDA high, SCL low, WP disabled by SK at bit 0, D0, GPIOL0 at bit 1
    OutputBuffer[dwNumBytesToSend++] = '\x13'; //Set SK,D0,GPIOL0 pins as output with bit '', other pins as input with bit `'
    HighSpeedSetI2CStop();
    //Send off the commands
    ftStatus = FT_Write(ftHandle, OutputBuffer, dwNumBytesToSend, &dwNumBytesSent); dwNumBytesToSend = 0; //Clear output buffer
}

#endif

@end
