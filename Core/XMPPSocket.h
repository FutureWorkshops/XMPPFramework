//
//  XMPPSocket.h
//  XMPPFramework
//
//  Created by Igor Fereira on 29/11/2018.
//  Copyright © 2018 XMPPFramework. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol XMPPSocketDelegate;

/**
 This class wraps around the Web & TCP sockets into a single entity, to separate the comunication layer from the stream control
 */
@interface XMPPSocket : NSObject

@property (nonatomic, assign) BOOL preferIPv6;
@property (nonatomic, weak, nullable) id<XMPPSocketDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithProcessQueue:(dispatch_queue_t)processQueue NS_DESIGNATED_INITIALIZER;

- (void) disconnectAfterWriting;
- (void) startTLS:(NSDictionary * _Nullable)configuration;
- (void) setSSLCertificates:(NSArray<NSData *> * _Nullable)certificates;
- (BOOL) connectToP2POnAddress:(NSData *)address error:(NSError * _Nullable __autoreleasing *)error NS_SWIFT_NAME(connectToP2P(address:));
- (void) connectToHost:(NSString *)host onPort:(NSUInteger)port NS_SWIFT_NAME(connect(host:port:));
- (void) writeData:(NSData *)data withTag:(long)tag andTimeout:(NSTimeInterval)timeout NS_SWIFT_NAME(write(_:tag:timeout:));
- (void) readDataWithTimeout:(NSTimeInterval)timeout andTag:(long)tag NS_SWIFT_NAME(readData(timeout:tag:));
- (void) disconnect;

@end

@protocol XMPPSocketDelegate <NSObject>

- (void)socket:(XMPPSocket *)socket didDisconnectWithError:(NSError * _Nullable)error;
- (void)socket:(XMPPSocket *)socket didConnectToAddress:(NSData *)address;
- (void)socket:(XMPPSocket *)socket didReceiveMessage:(NSData *)message;
- (void)socket:(XMPPSocket *)socket didWriteDataWithTag:(long)tag;

@optional
- (void)socketDidSecureConnection:(XMPPSocket *)socket;
- (void)socket:(XMPPSocket *)socket didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler NS_SWIFT_NAME(didReceivedTrust(socket:trust:completion:));

@end

NS_ASSUME_NONNULL_END
