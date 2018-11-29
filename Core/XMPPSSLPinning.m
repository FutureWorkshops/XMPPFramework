//
//  XMPPSSLPinning.m
//  XMPPFramework
//
//  Created by Igor Fereira on 29/11/2018.
//  Copyright © 2018 XMPPFramework. All rights reserved.
//

#import "XMPPSSLPinning.h"

@interface XMPPSSLPinning ()

@property (nonatomic, copy) dispatch_queue_t processQueue;

@end

@implementation XMPPSSLPinning

- (instancetype) initWithSSLCertificates:(NSArray<NSData *> *)certificates {
    self = [super init];
    if (self) {
        self->_processQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        NSMutableArray *certificateReferences = [NSMutableArray arrayWithCapacity:certificates.count];
        for (NSData *data in certificates) {
            CFDataRef certDataRef = (__bridge CFDataRef)data;
            SecCertificateRef certRef = SecCertificateCreateWithData(NULL, certDataRef);
            if (certRef != NULL) {
                [certificateReferences addObject:(__bridge id)certRef];
            }
        }
        
        self->_sslCertificates = [certificateReferences copy];
    }
    return self;
}

+ (void) basicEvaluationOfTrust:(SecTrustRef)trust withCompletion:(SSLPinningResult)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SecTrustResultType result = kSecTrustResultDeny;
        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            completion(YES);
        }
        else {
            completion(NO);
        }
    });
}

- (void) evaluate:(SecTrustRef)trust withCompletion:(SSLPinningResult)completion {
    
    if (self.sslCertificates.count > 0) {
        NSArray *certificates = [self.sslCertificates copy];
        dispatch_async(self.processQueue, ^{
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
            
            completion(pinnedCertFound);
        });
    } else {
        [XMPPSSLPinning basicEvaluationOfTrust:trust withCompletion:completion];
    }
}

@end
