//
//  FDGdbServer.m
//  Sync
//
//  Created by Denis Bohm on 4/28/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDGdbServer.h"

#import <ARMSerialWireDebug/FDLogger.h>

@protocol FDGdbServerPacketDelegate <NSObject>

- (void)packetInterrupt;
- (void)packetSuccess:(NSData *)data;
- (void)packetFailure:(NSData *)data;

@end

typedef enum {
    WaitForStart,
    WaitForContent,
    WaitForEscaped,
    WaitForChecksum1,
    WaitForChecksum2
} FDGdbServerParserState;

@interface FDGdbServerParser : NSObject

@property (weak) id<FDGdbServerPacketDelegate> delegate;

@property FDLogger *logger;
@property FDGdbServerParserState state;
@property uint8_t checksumUpper;
@property NSMutableData *packet;

@end

static
uint8_t hex(uint8_t byte) {
	if (('a' <= byte) && (byte <= 'f')) {
		return byte - 'a' + 10;
    }
	if (('A' <= byte) && (byte <= 'F')) {
		return byte - 'A' + 10;
    }
	if (('0' <= byte) && (byte <= '9')) {
		return byte - '0';
    }
	return 0;
}

static
uint8_t checksum(NSData *data) {
    uint8_t checksum = 0;
    uint8_t *bytes = (uint8_t *)data.bytes;
    NSUInteger length = data.length;
    for (NSUInteger i = 0; i < length; ++i) {
        checksum += bytes[i];
    }
    return checksum;
}

@implementation FDGdbServerParser

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        _state = WaitForStart;
    }
    return self;
}

- (NSArray *)append:(NSData *)data
{
    NSMutableArray *packets = [NSMutableArray array];
    uint8_t *bytes = (uint8_t *)data.bytes;
    NSUInteger length = data.length;
    for (NSUInteger i = 0; i < length; ++i) {
        uint8_t byte = bytes[i];
        switch (_state) {
            case WaitForStart: {
                if (byte == 0x03) {
                    [_delegate packetInterrupt];
                } else
                if (byte == '$') {
                    _state = WaitForContent;
                    _packet = [NSMutableData data];
                }
            } break;
            case WaitForContent: {
                if (byte == '}') {
                    _state = WaitForEscaped;
                } else
                if (byte == '#') {
                    _state = WaitForChecksum1;
                } else {
                    [_packet appendBytes:&byte length:1];
                }
            } break;
            case WaitForEscaped: {
                uint8_t escaped = byte ^ 0x20;
                [_packet appendBytes:&escaped length:1];
                _state = WaitForContent;
            } break;
            case WaitForChecksum1: {
                _checksumUpper = byte;
                _state = WaitForChecksum2;
            } break;
            case WaitForChecksum2: {
                NSData *packet = _packet;
                _state = WaitForStart;
                _packet = nil;
                uint8_t verify = (hex(_checksumUpper) << 4) | hex(byte);
                uint8_t actual = checksum(packet);
                if ((packet.length > 0) && (verify == actual)) {
                    [_delegate packetSuccess:packet];
                } else {
                    FDLog(@"checksum mismatch");
                    [_delegate packetFailure:packet];
                }
            } break;
        }
    }
    return packets;
}

@end

@interface FDGdbServer () <FDGdbServerPacketDelegate>

@property NSSocketPort *socketPort;
@property NSFileHandle *socketFileHandle;
@property NSFileHandle *clientFileHandle;
@property FDGdbServerParser *parser;

@end

@implementation FDGdbServer

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        _port = 9000;
        _parser = [[FDGdbServerParser alloc] init];
        _parser.delegate = self;
    }
    return self;
}

- (void)start
{
    _socketPort = [[NSSocketPort alloc] initWithTCPPort:_port];
    int fd = [_socketPort socket];
    _socketFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(newConnection:)
                               name:NSFileHandleConnectionAcceptedNotification
                             object:nil];
    [_socketFileHandle acceptConnectionInBackgroundAndNotify];
    FDLog(@"gdb server ready to accept a connection");
}

- (void)newConnection:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSNumber *error = [userInfo objectForKey:@"NSFileHandleError"];
    if (error) {
        FDLog(@"NSFileHandle Error: %@", error);
        return;
    }
    
    [_socketFileHandle acceptConnectionInBackgroundAndNotify];
    
    _clientFileHandle = [userInfo objectForKey:NSFileHandleNotificationFileHandleItem];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(dataReceivedNotification:)
                               name:NSFileHandleReadCompletionNotification
                             object:_clientFileHandle];
    [_clientFileHandle readInBackgroundAndNotify];
    
    [self performSelectorOnDelegate:@selector(gdbConnected)];
    self.connected = YES;
    FDLog(@"gdb server accepted a connection");
}

- (void)dataReceivedNotification:(NSNotification *)notification
{
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if (data.length == 0) {
        _clientFileHandle = nil;
        [self performSelectorOnDelegate:@selector(gdbDisconnected)];
        self.connected = NO;
        FDLog(@"gdb server disconnected");
        return;
    }
    
    [_clientFileHandle readInBackgroundAndNotify];

    FDLog(@"gdb server received data %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
    [_parser append:data];
}

- (void)sendAck:(BOOL)success
{
    uint8_t byte = success ? '+' : '-';
    FDLog(@"gdb ack: %c", byte);
    [_clientFileHandle writeData:[NSData dataWithBytes:&byte length:1]];
}

- (void)notify:(NSString *)string {
    NSMutableString *response = [NSMutableString stringWithString:@"%"];
    uint8_t checksum = 0;
    for (NSUInteger i = 0; i < string.length; ++i) {
        uint8_t byte = [string characterAtIndex:i];
        switch (byte) {
            case '$':
            case '#':
            case '}':
                [response appendFormat:@"}%c", byte ^ 0x20];
                break;
                break;
            default:
                [response appendFormat:@"%c", byte];
                break;
        }
        checksum += byte;
    }
    [response appendFormat:@"#%02x", checksum];
    FDLog(@"gdb tx: %@", response);
    [_clientFileHandle writeData:[response dataUsingEncoding:NSASCIIStringEncoding]];
}

- (void)respond:(NSString *)string {
    NSMutableString *response = [NSMutableString stringWithString:@"$"];
    uint8_t checksum = 0;
    for (NSUInteger i = 0; i < string.length; ++i) {
        uint8_t byte = [string characterAtIndex:i];
        switch (byte) {
            case '$':
            case '#':
            case '}':
                [response appendFormat:@"}%c", byte ^ 0x20];
                break;
                break;
            default:
                [response appendFormat:@"%c", byte];
                break;
        }
        checksum += byte;
    }
    [response appendFormat:@"#%02x", checksum];
    FDLog(@"gdb tx: %@", response);
    [_clientFileHandle writeData:[response dataUsingEncoding:NSASCIIStringEncoding]];
}

- (void)packetInterrupt
{
    [self performSelectorOnDelegate:@selector(gdbInterrupt)];
}

static
BOOL startsWith(NSData *data, NSString *command) {
    if (data.length < command.length) {
        return NO;
    }
    uint8_t *bytes = (uint8_t *)data.bytes;
    for (NSUInteger i = 0; i < command.length; ++i) {
        if (bytes[i] != [command characterAtIndex:i]) {
            return NO;
        }
    }
    return YES;
}

- (void)packetSuccess:(NSData *)data
{
    FDLog(@"gdb rx: %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
    
    [self sendAck:true];
    SEL selector = nil;
    uint8_t *bytes = (uint8_t *)data.bytes;
    uint8_t byte = bytes[0];
    switch (byte) {
        case '?':
            selector = @selector(gdbServerReportStopReason:);
            break;
        case 'c':
            selector = @selector(gdbServerContinue:);
            break;
        case 'C':
            selector = @selector(gdbServerContinueWithSignal:);
            break;
        case 's':
            selector = @selector(gdbServerStep:);
            break;
        case 'S':
            selector = @selector(gdbServerStepWithSignal:);
            break;
        case 'D':
            selector = @selector(gdbServerDetach:);
            break;
        case 'g':
            selector = @selector(gdbServerReadRegisters:);
            break;
        case 'G':
            selector = @selector(gdbServerWriteRegisters:);
            break;
        case 'k':
            selector = @selector(gdbServerKill:);
            break;
        case 'm':
            selector = @selector(gdbServerReadMemory:);
            break;
        case 'M':
            selector = @selector(gdbServerWriteMemory:);
            break;
        case 'p':
            selector = @selector(gdbServerReadRegister:);
            break;
        case 'P':
            selector = @selector(gdbServerWriteRegister:);
            break;
        case 'x':
            selector = @selector(gdbServerLoad:);
            break;
        case 'z':
            selector = @selector(gdbServerClearPoints:);
            break;
        case 'Z':
            selector = @selector(gdbServerSetPoints:);
            break;
        case 'q':
            if (startsWith(data, @"qC")) {
                selector = @selector(gdbServerReportThread:);
            } else
            if (startsWith(data, @"qH")) {
                selector = @selector(gdbServerSetThread:);
            } else
            if (startsWith(data, @"qOffsets")) {
                selector = @selector(gdbServerReportOffsets:);
            } else
            if (startsWith(data, @"qSupported")) {
                selector = @selector(gdbServerReportSupported:);
            } else
            if (startsWith(data, @"qSymbol::")) {
                selector = @selector(gdbServerRequestSymbols:);
            } else
            if (startsWith(data, @"qXfer")) {
                selector = @selector(gdbServerTransfer:);
            }
            break;
        case '!':
            selector = @selector(gdbServerExtendedRemoteDebugging:);
            break;
        case 'R':
            selector = @selector(gdbServerRestart:);
            break;
        case 'v':
            if (startsWith(data, @"vAttach")) {
                selector = @selector(gdbServerAttach:);
            } else
            if (startsWith(data, @"vRun")) {
                selector = @selector(gdbServerRun:);
            } else
            if (startsWith(data, @"vCont?")) {
                selector = @selector(gdbServerReportVCont:);
            }
            break;
    }
    [self performSelectorOnDelegate:selector withObject:data];
}

- (void)performSelectorOnDelegate:(SEL)selector withObject:(id)object
{
    if ([_delegate respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_delegate performSelector:selector withObject:object];
#pragma clang diagnostic pop
    } else {
        [self respond:@""];
    }
}

- (void)performSelectorOnDelegate:(SEL)selector
{
    if ([_delegate respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_delegate performSelector:selector];
#pragma clang diagnostic pop
    }
}

- (void)packetFailure:(NSData *)data
{
    [self sendAck:false];
}

@end
