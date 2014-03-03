//
//  FDSerialPort.m
//  FireflyRML
//
//  Created by Denis Bohm on 12/5/13.
//  Copyright (c) 2013 Firefly Design LLC. All rights reserved.
//

#import "FDSerialPort.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <paths.h>
#include <termios.h>
#include <unistd.h>
#include <sysexits.h>
#include <sys/param.h>
#include <sys/select.h>
#include <sys/time.h>
#include <time.h>
#include <AvailabilityMacros.h>

#include <CoreFoundation/CoreFoundation.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#if defined(MAC_OS_X_VERSION_10_3) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_3)
#include <IOKit/serial/ioss.h>
#endif
#include <IOKit/IOBSD.h>

// Hold the original termios attributes so we can reset them
static struct termios gOriginalTTYAttrs;

@interface FDSerialPort ()

@property NSFileHandle *fileHandle;
@property NSMutableData* writeBuffer;

@end

@implementation FDSerialPort

+ (NSArray *)findSerialPorts
{
    NSMutableArray *paths = [NSMutableArray array];
    kern_return_t       kernResult;
    mach_port_t         masterPort;
    CFMutableDictionaryRef  classesToMatch;
    
    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        printf("IOMasterPort returned %d\n", kernResult);
        goto exit;
    }
    
    // Serial devices are instances of class IOSerialBSDClient.
    classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL)
    {
        printf("IOServiceMatching returned a NULL dictionary.\n");
    }
    else {
        CFDictionarySetValue(classesToMatch,
                             CFSTR(kIOSerialBSDTypeKey),
                             CFSTR(kIOSerialBSDAllTypes));
        
        // Each serial device object has a property with key
        // kIOSerialBSDTypeKey and a value that is one of
        // kIOSerialBSDAllTypes, kIOSerialBSDModemType,
        // or kIOSerialBSDRS232Type. You can change the
        // matching dictionary to find other types of serial
        // devices by changing the last parameter in the above call
        // to CFDictionarySetValue.
    }
    
    io_iterator_t matchingServices;
    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, &matchingServices);
    if (KERN_SUCCESS != kernResult)
    {
        printf("IOServiceGetMatchingServices returned %d\n", kernResult);
        goto exit;
    }
    
    io_object_t     service;
    while((service= IOIteratorNext(matchingServices)))
    {
        CFTypeRef   deviceFilePathAsCFString;
        
        // Get the callout device's path (/dev/cu.xxxxx).
        // The callout device should almost always be
        // used. You would use the dialin device (/dev/tty.xxxxx) when
        // monitoring a serial port for
        // incoming calls, for example, a fax listener.
        
        deviceFilePathAsCFString = IORegistryEntryCreateCFProperty(service,
                                                                   CFSTR(kIOCalloutDeviceKey),
                                                                   kCFAllocatorDefault,
                                                                   0);
        if (deviceFilePathAsCFString)
        {
            NSString *path = (__bridge NSString *)(deviceFilePathAsCFString);
            [paths addObject:path];
        }
        
        
        // Release the io_service_t now that we are done with it.
        
        (void) IOObjectRelease(service);
    }
    
exit:
    return paths;
}

- (id)init
{
    if (self = [super init]) {
        _baudRate = 9600;
    }
    return self;
}

- (int)openFileDescriptor
{
    const char *bsdPath = [_path cStringUsingEncoding:NSASCIIStringEncoding];
    int             fileDescriptor = -1;
    struct termios  options;
    
    // Open the serial port read/write, with no controlling terminal, and don't wait for a connection.
    // The O_NONBLOCK flag also causes subsequent I/O on the device to be non-blocking.
    // See open(2) ("man 2 open") for details.
    
    fileDescriptor = open(bsdPath, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fileDescriptor == -1)
    {
        printf("Error opening serial port %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
        goto error;
    }
    
    // Note that open() follows POSIX semantics: multiple open() calls to the same file will succeed
    // unless the TIOCEXCL ioctl is issued. This will prevent additional opens except by root-owned
    // processes.
    // See tty(4) ("man 4 tty") and ioctl(2) ("man 2 ioctl") for details.
    
    if (ioctl(fileDescriptor, TIOCEXCL) == -1)
    {
        printf("Error setting TIOCEXCL on %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
        goto error;
    }
    
    // Now that the device is open, clear the O_NONBLOCK flag so subsequent I/O will block.
    // See fcntl(2) ("man 2 fcntl") for details.
    
    if (fcntl(fileDescriptor, F_SETFL, 0) == -1)
    {
        printf("Error clearing O_NONBLOCK %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
        goto error;
    }
    
    // Get the current options and save them so we can restore the default settings later.
    if (tcgetattr(fileDescriptor, &gOriginalTTYAttrs) == -1)
    {
        printf("Error getting tty attributes %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
        goto error;
    }
    
    // The serial port attributes such as timeouts and baud rate are set by modifying the termios
    // structure and then calling tcsetattr() to cause the changes to take effect. Note that the
    // changes will not become effective without the tcsetattr() call.
    // See tcsetattr(4) ("man 4 tcsetattr") for details.
    
    options = gOriginalTTYAttrs;
    
    // Print the current input and output baud rates.
    // See tcsetattr(4) ("man 4 tcsetattr") for details.
    
    printf("Current input baud rate is %d\n", (int) cfgetispeed(&options));
    printf("Current output baud rate is %d\n", (int) cfgetospeed(&options));
    
    // Set raw input (non-canonical) mode, with reads blocking until either a single character
    // has been received or a one second timeout expires.
    // See tcsetattr(4) ("man 4 tcsetattr") and termios(4) ("man 4 termios") for details.
    
    cfmakeraw(&options);
    options.c_cc[VMIN] = 1;
    options.c_cc[VTIME] = 10;
    
    // The baud rate, word length, and handshake options can be set as follows:
    
    cfsetspeed(&options, _baudRate);       // Set baud rate
    options.c_cflag = (CS8|CREAD|CRTSCTS);//        |    // Use 8 bit words
    //                        PARENB     |    // Parity enable (even parity if PARODD not also set)
    //                        CCTS_OFLOW |    // CTS flow control of output
    //                        CRTS_IFLOW);    // RTS flow control of input
    
#if defined(MAC_OS_X_VERSION_10_4) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4)
    // Starting with Tiger, the IOSSIOSPEED ioctl can be used to set arbitrary baud rates
    // other than those specified by POSIX. The driver for the underlying serial hardware
    // ultimately determines which baud rates can be used. This ioctl sets both the input
    // and output speed.
    
    speed_t speed = _baudRate; // Set baud rate
    if (ioctl(fileDescriptor, IOSSIOSPEED, &speed) == -1)
    {
        printf("Error calling ioctl(..., IOSSIOSPEED, ...) %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
    }
#endif
    
    // Print the new input and output baud rates. Note that the IOSSIOSPEED ioctl interacts with the serial driver
    // directly bypassing the termios struct. This means that the following two calls will not be able to read
    // the current baud rate if the IOSSIOSPEED ioctl was used but will instead return the speed set by the last call
    // to cfsetspeed.
    
    printf("Input baud rate changed to %d\n", (int) cfgetispeed(&options));
    printf("Output baud rate changed to %d\n", (int) cfgetospeed(&options));
    
    // Cause the new options to take effect immediately.
    if (tcsetattr(fileDescriptor, TCSANOW, &options) == -1)
    {
        printf("Error setting tty attributes %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
        goto error;
    }
    
    /*
     // To set the modem handshake lines, use the following ioctls.
     // See tty(4) ("man 4 tty") and ioctl(2) ("man 2 ioctl") for details.
     
     if (ioctl(fileDescriptor, TIOCSDTR) == -1) // Assert Data Terminal Ready (DTR)
     {
     printf("Error asserting DTR %s - %s(%d).\n",
     bsdPath, strerror(errno), errno);
     }
     
     if (ioctl(fileDescriptor, TIOCCDTR) == -1) // Clear Data Terminal Ready (DTR)
     {
     printf("Error clearing DTR %s - %s(%d).\n",
     bsdPath, strerror(errno), errno);
     }
     
     int             handshake;
     handshake = TIOCM_DTR | TIOCM_RTS | TIOCM_CTS | TIOCM_DSR;
     if (ioctl(fileDescriptor, TIOCMSET, &handshake) == -1)
     // Set the modem lines depending on the bits set in handshake
     {
     printf("Error setting handshake lines %s - %s(%d).\n",
     bsdPath, strerror(errno), errno);
     }
     
     // To read the state of the modem lines, use the following ioctl.
     // See tty(4) ("man 4 tty") and ioctl(2) ("man 2 ioctl") for details.
     
     if (ioctl(fileDescriptor, TIOCMGET, &handshake) == -1)
     // Store the state of the modem lines in handshake
     {
     printf("Error getting handshake lines %s - %s(%d).\n",
     bsdPath, strerror(errno), errno);
     }
     
     printf("Handshake lines currently set to %d\n", handshake);
     */
    
#if defined(MAC_OS_X_VERSION_10_3) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_3)
    unsigned long mics = 1UL;
    
    // Set the receive latency in microseconds. Serial drivers use this value to determine how often to
    // dequeue characters received by the hardware. Most applications don't need to set this value: if an
    // app reads lines of characters, the app can't do anything until the line termination character has been
    // received anyway. The most common applications which are sensitive to read latency are MIDI and IrDA
    // applications.
    
    if (ioctl(fileDescriptor, IOSSDATALAT, &mics) == -1)
    {
        // set latency to 1 microsecond
        printf("Error setting read latency %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
        goto error;
    }
#endif
    
    // Success
    return fileDescriptor;
    
    // Failure path
error:
    if (fileDescriptor != -1)
    {
        close(fileDescriptor);
    }
    
    return -1;
}

- (void)purge
{
    _writeBuffer.length = 0;
}

- (void)writeData:(NSData *)data
{
    [_writeBuffer appendData:data];
    if ((_writeBuffer > 0) && (_fileHandle.writeabilityHandler == nil)) {
        //        NSLog(@"setting writeabilityHandler");
        __weak id me = self;
        _fileHandle.writeabilityHandler = ^(NSFileHandle *fh) {
            [me writable];
        };
    }
}

- (void)writable
{
    int fd = _fileHandle.fileDescriptor;
    uint8_t *bytes = (uint8_t *)_writeBuffer.bytes;
    NSUInteger length = _writeBuffer.length;
	long n = write(fd, bytes, length);
	if (n < 0) {
		NSLog(@"Error opening serial port %@ - %s(%d).\n", _path, strerror(errno), errno);
	} else
        if (n > 0) {
            [_writeBuffer replaceBytesInRange:NSMakeRange(0, n) withBytes:nil length:0];
        }
    
    //    NSLog(@"%lu bytes remaining to be written", _writeBuffer.length);
    if (_writeBuffer.length <= 0) {
        //        NSLog(@"clearing writeabilityHandler");
        _fileHandle.writeabilityHandler = nil;
    }
}

- (void)readable
{
    NSData *data = [_fileHandle availableData];
    //    NSLog(@"fileHandleReadComplete data.length=%lu", data.length);
    
    [_delegate serialPort:self didReceiveData:data];
}

- (void)open
{
    int fd = [self openFileDescriptor];
    if (fd == -1) {
        NSLog(@"error opening serial port file: %@", _path);
    }
    
    _writeBuffer = [NSMutableData data];
    
    _fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    __weak id me = self;
    _fileHandle.readabilityHandler = ^(NSFileHandle *fh) {
        [me readable];
    };
    
    NSLog(@"serial port %@ has been opened", _path);
}

- (void)close
{
    _fileHandle = nil;
    
    NSLog(@"serial port %@ has been closed", _path);
}

@end
