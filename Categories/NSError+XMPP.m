//
//  NSError+XMPP.m
//  XMPPFramework
//
//  Created by Igor Fereira on 29/11/2018.
//  Copyright © 2018 XMPPFramework. All rights reserved.
//

#import "NSError+XMPP.h"

NSString *const XMPPStreamErrorDomain = @"XMPPStreamErrorDomain";

@implementation NSError (XMPP)

+ (NSError *) xmppStreamErrorWithCode:(NSInteger)errorCode userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo {
    return [NSError errorWithDomain:XMPPStreamErrorDomain code:errorCode userInfo:userInfo];
}

@end
