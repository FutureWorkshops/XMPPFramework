//
//  XMPPSocket.m
//  XMPPFramework
//
//  Created by Igor Fereira on 29/11/2018.
//  Copyright © 2018 XMPPFramework. All rights reserved.
//

#import "XMPPSocket.h"
#import "NSError+XMPP.h"
@import SocketRocket;
@import CocoaAsyncSocket;

@interface XMPPSocket () <GCDAsyncSocketDelegate, SRWebSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *tcpSocket;
@property (nonatomic, strong) SRWebSocket *webSocket;
@property (nonatomic, assign) BOOL isP2P;
@property (nonatomic, assign) dispatch_queue_t processQueue;
@property (nonatomic, copy) NSArray *sslCertificates;

@end

@implementation XMPPSocket

- (instancetype) initWithProcessQueue:(dispatch_queue_t)processQueue {
    self = [super init];
    if (self) {
        self->_processQueue = processQueue;
    }
    return self;
}

- (void) disconnectAfterWriting {
    if (self.isP2P) {
        [self.tcpSocket disconnectAfterWriting];
    }
}

- (void) startTLS:(NSDictionary * _Nullable)configuration {
    if (self.isP2P) {
        [self.tcpSocket startTLS:configuration];
    }
}

- (void) setSSLCertificates:(NSArray<NSData *> * _Nullable)certificates {
    if (certificates.count == 0) {
        self.sslCertificates = @[];
        return;
    }
    
    NSMutableArray *certificateReferences = [NSMutableArray arrayWithCapacity:certificates.count];
    for (NSData *data in certificates) {
        CFDataRef certDataRef = (__bridge CFDataRef)data;
        SecCertificateRef certRef = SecCertificateCreateWithData(NULL, certDataRef);
        if (certRef != NULL) {
            [certificateReferences addObject:(__bridge id)certRef];
        }
    }
    
    self.sslCertificates = [certificateReferences copy];
}

- (void) connectToHost:(NSString *)host onPort:(NSUInteger)port {
    [self disconnect];
    self.isP2P = NO;
    self.webSocket = [self _newWebSocketConnectToHost:host onPort:port];
    [self.webSocket open];
}

- (BOOL) connectToP2POnAddress:(NSData *)address error:(NSError * _Nullable __autoreleasing *)error {
    [self disconnect];
    self.isP2P = YES;
    if (self.tcpSocket == nil) {
        self.tcpSocket = [self _newTCPSocket];
    }
    return [self.tcpSocket connectToAddress:address error:error];
}

- (void) writeData:(NSData *)data withTag:(long)tag andTimeout:(NSTimeInterval)timeout {
    if (self.isP2P) {
        [self.tcpSocket writeData:data withTimeout:timeout tag:tag];
    } else {
        [self.webSocket send:data];
    }
}

- (void) readDataWithTimeout:(NSTimeInterval)timeout andTag:(long)tag {
    if (!self.isP2P) {
        return;
    }
    
    [self.tcpSocket readDataWithTimeout:timeout tag:tag];
}

- (void)disconnect {
    [self.tcpSocket disconnect];
    [self.webSocket close];
}

#pragma mark - NSObject

- (void)dealloc {
    if (self.tcpSocket != nil) {
        [self.tcpSocket setDelegate:nil delegateQueue:NULL];
        [self.tcpSocket disconnect];
    }
    if (self.webSocket != nil) {
        [self.webSocket setDelegate:nil];
        [self.webSocket setDelegateDispatchQueue:NULL];
        [self.webSocket close];
    }
}

#pragma mark - Private methods

- (GCDAsyncSocket*) _newTCPSocket {
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.processQueue];
    socket.IPv4PreferredOverIPv6 = !self.preferIPv6;
    return socket;
}

- (SRWebSocket *) _newWebSocketConnectToHost:(NSString *)host onPort:(NSUInteger)port {
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:host];
    [components setPort:@(port)];
    if (![components.scheme isEqualToString:@"ws"] && ![components.scheme isEqualToString:@"wss"]) {
        [components setScheme:@"wss"];
    }
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[components URL]];
    [urlRequest setSR_SSLPinnedCertificates:self.sslCertificates];
    
    SRWebSocket *webSocket = [[SRWebSocket alloc] initWithURLRequest:urlRequest protocols:nil allowsUntrustedSSLCertificates:NO];
    [webSocket setDelegate:self];
    [webSocket setDelegateDispatchQueue:self.processQueue];
    return webSocket;
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    if (self.sslCertificates.count > 0) {
        NSArray *certificates = [self.sslCertificates copy];
        dispatch_async(bgQueue, ^{
            BOOL pinnedCertFound = NO;
            NSInteger numCerts = SecTrustGetCertificateCount(trust);
            for (NSInteger i = 0; i < numCerts && !pinnedCertFound; i++) {
                SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, i);
                NSData *certData = CFBridgingRelease(SecCertificateCopyData(cert));
                for (id ref in certificates) {
                    SecCertificateRef trustedCert = (__bridge SecCertificateRef)ref;
                    NSData *trustedCertData = CFBridgingRelease(SecCertificateCopyData(trustedCert));
                    if ([trustedCertData isEqual:certData]) {
                        pinnedCertFound = YES;
                        break;
                    }
                }
            }
            
            completionHandler(pinnedCertFound);
        });
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(socket:didReceiveTrust:completionHandler:)]) {
        [self.delegate socket:self didReceiveTrust:trust completionHandler:completionHandler];
        return;
    }

    // The delegate method should likely have code similar to this,
    // but will presumably perform some extra security code stuff.
    // For example, allowing a specific self-signed certificate that is known to the app.
    dispatch_async(bgQueue, ^{
        
        SecTrustResultType result = kSecTrustResultDeny;
        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            completionHandler(YES);
        }
        else {
            completionHandler(NO);
        }
    });
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    if ([self.delegate respondsToSelector:@selector(socketDidSecureConnection:)]) {
        [self.delegate socketDidSecureConnection:self];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self.delegate socket:self didConnectToAddress:sock.connectedAddress];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [self.delegate socket:self didDisconnectWithError:err];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    [self.delegate socket:self didWriteDataWithTag:tag];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [self.delegate socket:self didReceiveMessage:data];
}

#pragma mark - SRWebSocketDelegate

//TODO: Enable to SocketRocket to support tags, write notification and secured connection notification

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [self.delegate socket:self didConnectToAddress:[[webSocket.url absoluteString] dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSError *error = nil;
    if (!wasClean) {
        error = [NSError xmppStreamErrorWithCode:code userInfo:@{NSLocalizedDescriptionKey: reason}];
    }
    [self.delegate socket:self didDisconnectWithError:error];
}

-  (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self.delegate socket:self didDisconnectWithError:error];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSData *data = nil;
    if ([message isKindOfClass:[NSString class]]) {
        data = [((NSString *)message) dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([message isKindOfClass:[NSData class]]) {
        data = [((NSData *)message) copy];
    }
    
    if (data != nil) {
        [self.delegate socket:self didReceiveMessage:data];
    }
}

@end
