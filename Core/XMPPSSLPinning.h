//
//  XMPPSSLPinning.h
//  XMPPFramework
//
//  Created by Igor Fereira on 29/11/2018.
//  Copyright © 2018 XMPPFramework. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^SSLPinningResult)(BOOL shouldTrustPeer);

@interface XMPPSSLPinning : NSObject

@property (nonatomic, copy, readonly) NSArray *sslCertificates;

+ (void) basicEvaluationOfTrust:(SecTrustRef)trust withCompletion:(SSLPinningResult)completion NS_SWIFT_NAME(basicEvaluate(_:completion:));

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithSSLCertificates:(NSArray<NSData *> *)certificates NS_DESIGNATED_INITIALIZER;
- (void) evaluate:(SecTrustRef)trust withCompletion:(SSLPinningResult)completion NS_SWIFT_NAME(evaluate(_:completion:));

@end

NS_ASSUME_NONNULL_END
