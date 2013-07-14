//
//  FDGdbServer.h
//  Sync
//
//  Created by Denis Bohm on 4/28/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDLogger;

@protocol FDGdbServerDelegate <NSObject>

@optional

- (void)gdbConnected;
- (void)gdbDisconnected;

- (void)gdbServerReportStopReason:(NSData *)packet;
- (void)gdbServerContinue:(NSData *)packet;
- (void)gdbServerContinueWithSignal:(NSData *)packet;
- (void)gdbServerStep:(NSData *)packet;
- (void)gdbServerStepWithSignal:(NSData *)packet;
- (void)gdbServerDetach:(NSData *)packet;
- (void)gdbServerReadRegisters:(NSData *)packet;
- (void)gdbServerWriteRegisters:(NSData *)packet;
- (void)gdbServerKill:(NSData *)packet;
- (void)gdbServerReadMemory:(NSData *)packet;
- (void)gdbServerWriteMemory:(NSData *)packet;
- (void)gdbServerReadRegister:(NSData *)packet;
- (void)gdbServerWriteRegister:(NSData *)packet;
- (void)gdbServerLoad:(NSData *)packet;
- (void)gdbServerClearPoints:(NSData *)packet;
- (void)gdbServerSetPoints:(NSData *)packet;
- (void)gdbServerReportThread:(NSData *)packet;
- (void)gdbServerSetThread:(NSData *)packet;
- (void)gdbServerReportOffsets:(NSData *)packet;
- (void)gdbServerReportSupported:(NSData *)packet;
- (void)gdbServerRequestSymbols:(NSData *)packet;
- (void)gdbServerReportVCont:(NSData *)packet;
- (void)gdbServerTransfer:(NSData *)packet;

- (void)gdbServerExtendedRemoteDebugging:(NSData *)packet;
- (void)gdbServerRestart:(NSData *)packet;
- (void)gdbServerAttach:(NSData *)packet;
- (void)gdbServerRun:(NSData *)packet;    

- (void)gdbInterrupt;

@end

@interface FDGdbServer : NSObject

@property FDLogger *logger;
@property unsigned short port;
@property (weak) id<FDGdbServerDelegate> delegate;
@property BOOL connected;

- (void)start;

- (void)respond:(NSString *)string;
- (void)notify:(NSString *)string;

@end
