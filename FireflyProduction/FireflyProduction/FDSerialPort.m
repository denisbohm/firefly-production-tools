//
//  FDSerialPort.m
//  FireflyProduction
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
#include <IOKit/usb/IOUSBLib.h>

// Hold the original termios attributes so we can reset them
static struct termios gOriginalTTYAttrs;

@implementation FDSerialPortMatcherUSB

+ (FDSerialPortMatcherUSB *)matcher:(uint16_t)vid pid:(uint16_t)pid
{
    return [[FDSerialPortMatcherUSB alloc] init:vid pid:pid];
}

- (id)init:(uint16_t)vid pid:(uint16_t)pid
{
    if (self = [super init]) {
        _vid = vid;
        _pid = pid;
    }
    return self;
}

- (BOOL)matches:(io_object_t)serialService
{
    // walk up the hierarchy until we find the entry with USB vendor id and product id
    io_registry_entry_t parent;
    kern_return_t result = IORegistryEntryGetParentEntry(serialService, kIOServicePlane, &parent);
    while (result == KERN_SUCCESS) {
        CFTypeRef vendorIdAsCFNumber  = IORegistryEntrySearchCFProperty(parent, kIOServicePlane, CFSTR(kUSBVendorID),  kCFAllocatorDefault, 0);
        CFTypeRef productIdAsCFNumber = IORegistryEntrySearchCFProperty(parent, kIOServicePlane, CFSTR(kUSBProductID), kCFAllocatorDefault, 0);
        if (vendorIdAsCFNumber && productIdAsCFNumber) {
            int vid = 0;
            CFNumberGetValue((CFNumberRef)vendorIdAsCFNumber, kCFNumberIntType, &vid);
            CFRelease(vendorIdAsCFNumber);
            int pid = 0;
            CFNumberGetValue((CFNumberRef)productIdAsCFNumber, kCFNumberIntType, &pid);
            CFRelease(productIdAsCFNumber);
            IOObjectRelease(parent);
            return (vid == _vid) && (pid == _pid);
        }
        io_registry_entry_t oldparent = parent;
        result = IORegistryEntryGetParentEntry(parent, kIOServicePlane, &parent);
        IOObjectRelease(oldparent);
    }
    return NO;
}

@end

@interface FDSerialPort ()

@property NSFileHandle *fileHandle;
@property NSMutableData* writeBuffer;

@end

@implementation FDSerialPort

+ (NSArray *)findSerialPorts
{
    return [FDSerialPort findSerialPorts:nil];
}

+ (NSArray *)findSerialPorts:(NSSet *)matchers;
{
    NSMutableArray *paths = [NSMutableArray array];
    
    mach_port_t masterPort;
    kern_return_t kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult) {
        printf("IOMasterPort returned %d\n", kernResult);
        goto exit;
    }
    
    // Serial devices are instances of class IOSerialBSDClient.
    CFMutableDictionaryRef classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL) {
        printf("IOServiceMatching returned a NULL dictionary.\n");
    } else {
        // We can search for kIOSerialBSDAllTypes, kIOSerialBSDModemType, or kIOSerialBSDRS232Type.
        CFDictionarySetValue(classesToMatch, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
    }
    
    io_iterator_t matchingServices;
    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, &matchingServices);
    if (KERN_SUCCESS != kernResult) {
        printf("IOServiceGetMatchingServices returned %d\n", kernResult);
        goto exit;
    }
    
    io_object_t service;
    while ((service = IOIteratorNext(matchingServices))) {
        BOOL matches = YES;
        if (matchers != nil) {
            matches = NO;
            for (id<FDSerialPortMatcher> matcher in matchers) {
                if ([matcher matches:service]) {
                    matches = YES;
                    break;
                }
            }
        }
        
        if (matches) {
            CFTypeRef deviceFilePathAsCFString = IORegistryEntryCreateCFProperty(service, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0);
            if (deviceFilePathAsCFString) {
                NSString *path = (__bridge NSString *)(deviceFilePathAsCFString);
                [paths addObject:path];
            }
        }
        
        (void) IOObjectRelease(service);
    }
    
exit:
    return paths;
}

// ---------------------------------------------------------------------------------
//
// AllocateHIDObjectFromIOHIDDeviceRef()
//
// returns:
// NULL, or acceptable io_object_t
//
// ---------------------------------------------------------------------------------
io_service_t AllocateHIDObjectFromIOHIDDeviceRef(IOHIDDeviceRef inIOHIDDeviceRef) {
    io_service_t result = 0L;
    if (inIOHIDDeviceRef) {
        // Set up the matching criteria for the devices we're interested in.
        // We are interested in instances of class IOHIDDevice.
        // matchingDict is consumed below(in IOServiceGetMatchingService)
        // so we have no leak here.
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOHIDDeviceKey);
        if (matchingDict) {
            // Add a key for locationID to our matching dictionary.  This works for matching to
            // IOHIDDevices, so we will only look for a device attached to that particular port
            // on the machine.
            CFTypeRef tCFTypeRef = IOHIDDeviceGetProperty(inIOHIDDeviceRef, CFSTR(kIOHIDLocationIDKey));
            if (tCFTypeRef) {
                CFDictionaryAddValue(matchingDict, CFSTR(kIOHIDLocationIDKey), tCFTypeRef);
                
                // IOServiceGetMatchingService assumes that we already know that there is only one device
                // that matches.  This way we don't have to do the whole iteration dance to look at each
                // device that matches.  This is a new API in 10.2
                result = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDict);
                // (matchingDict is released by IOServiceGetMatchingServices)
            } else {
                CFRelease(matchingDict);
            }
        }
    }
    
    return (result);
}   // AllocateHIDObjectFromIOHIDDeviceRef

// ---------------------------------------------------------------------------------
//
// FreeHIDObject()
//
// ---------------------------------------------------------------------------------
bool FreeHIDObject(io_service_t inHIDObject) {
    kern_return_t kr;
    
    kr = IOObjectRelease(inHIDObject);
    
    return (kIOReturnSuccess == kr);
} // FreeHIDObject

+ (NSString *)getSerialPortPathWithService:(io_service_t)service
{
    NSString *path = nil;
    CFTypeRef deviceFilePathAsCFString = IORegistryEntrySearchCFProperty(service, kIOServicePlane, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, kIORegistryIterateRecursively);
    if (deviceFilePathAsCFString) {
        path = (__bridge NSString *)(deviceFilePathAsCFString);
    }
    return path;
}

+ (NSString *)getSerialPortPath:(IOHIDDeviceRef)deviceRef
{
    NSString *path = nil;
    io_service_t service = AllocateHIDObjectFromIOHIDDeviceRef(deviceRef);
    if (service) {
        path = [FDSerialPort getSerialPortPathWithService:service];
        FreeHIDObject(service);
    }
    return path;
}

- (id)init
{
    if (self = [super init]) {
        _baudRate = 9600;
        _dataBits = 8;
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
    
//    printf("Current input baud rate is %d\n", (int) cfgetispeed(&options));
//    printf("Current output baud rate is %d\n", (int) cfgetospeed(&options));
    
    // Set raw input (non-canonical) mode, with reads blocking until either a single character
    // has been received or a one second timeout expires.
    // See tcsetattr(4) ("man 4 tcsetattr") and termios(4) ("man 4 termios") for details.
    
    cfmakeraw(&options);
    options.c_cc[VMIN] = 1;
    options.c_cc[VTIME] = 10;
    
    // The baud rate, word length, and handshake options can be set as follows:
    
    cfsetspeed(&options, _baudRate); // Set baud rate
    options.c_cflag = CREAD | CRTSCTS;
    switch (_dataBits) {
        case 8:
            options.c_cflag |= CS8;
            break;
        case 7:
            options.c_cflag |= CS7;
            break;
        case 6:
            options.c_cflag |= CS6;
            break;
        case 5:
            options.c_cflag |= CS5;
            break;
    }
    switch (_parity) {
        case FDSerialPortParityEven:
            options.c_cflag |= PARENB;
            break;
        case FDSerialPortParityOdd:
            options.c_cflag |= PARENB | PARODD;
            break;
        default:
            break;
    }
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
    
//    printf("Input baud rate changed to %d\n", (int) cfgetispeed(&options));
//    printf("Output baud rate changed to %d\n", (int) cfgetospeed(&options));
    
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
//    NSLog(@"fileHandleReadComplete data.length=%lu data=%@", data.length, data);
    if (data.length > 0) {
        [_delegate serialPort:self didReceiveData:data];
    }
}

- (void)open
{
    int fd = [self openFileDescriptor];
    if (fd == -1) {
        @throw [NSException exceptionWithName:@"SerialPortOpenError" reason:[NSString stringWithFormat:@"error opening serial port file: %@", _path] userInfo:nil];
    }
    
    _writeBuffer = [NSMutableData data];
    
    _fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    __weak id me = self;
    _fileHandle.readabilityHandler = ^(NSFileHandle *fh) {
        [me readable];
    };
    
//    NSLog(@"serial port %@ has been opened", _path);
}

- (void)close
{
    _fileHandle = nil;
    
//    NSLog(@"serial port %@ has been closed", _path);
}

@end
