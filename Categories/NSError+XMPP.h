//
//  NSError+XMPP.h
//  XMPPFramework
//
//  Created by Igor Fereira on 29/11/2018.
//  Copyright © 2018 XMPPFramework. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSError (XMPP)

+ (NSError *) xmppStreamErrorWithCode:(NSInteger)errorCode userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;

@end

NS_ASSUME_NONNULL_END
