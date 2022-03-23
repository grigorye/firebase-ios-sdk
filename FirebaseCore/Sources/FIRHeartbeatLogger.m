// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

@import FirebaseCoreInternal;

#import "FirebaseCore/Extension/FIRAppInternal.h"
#import "FirebaseCore/Extension/FIRHeartbeatLogger.h"

// MARK: - FIRWeakContainer

/// A class used to weakly box reference types. This is used below to weakly store
/// `FIRHeartbeatLogger` instances in a dictionary.
@interface FIRWeakContainer<Object> : NSObject
@property(readonly, weak) Object object;
@end

@implementation FIRWeakContainer

+ (instancetype)containerWithObject:(id)obj {
  FIRWeakContainer *container = [[FIRWeakContainer alloc] init];
  container->_object = obj;
  return container;
}

@end

// MARK: - FIRHeartbeatLogger

NSString *_Nullable FIRHeaderValueFromHeartbeatsPayload(FIRHeartbeatsPayload *heartbeatsPayload) {
  if ([heartbeatsPayload isEmpty]) {
    return nil;
  }

  return [heartbeatsPayload headerValue];
}

@interface FIRHeartbeatLogger ()
@property(readonly) NSString *appID;
@property(readonly) FIRHeartbeatController *heartbeatController;
@property(copy, readonly) NSString * (^userAgentProvider)(void);
@end

@implementation FIRHeartbeatLogger

- (instancetype)initWithAppID:(NSString *)appID {
  return [self initWithAppID:appID userAgentProvider:[[self class] currentUserAgentProvider]];
}

- (instancetype)initWithAppID:(NSString *)appID
            userAgentProvider:(NSString * (^)(void))userAgentProvider {
  self = [super init];
  if (self) {
    _appID = [appID copy];
    _heartbeatController = [[FIRHeartbeatController alloc] initWithId:_appID];
    _userAgentProvider = [userAgentProvider copy];
  }
  return self;
}

+ (NSString * (^)(void))currentUserAgentProvider {
  return ^NSString * {
    return [FIRApp firebaseUserAgent];
  };
}

// MARK: - Instance Management

+ (NSMutableDictionary<NSString *, FIRWeakContainer<FIRHeartbeatLogger *> *> *)cachedInstances {
  static NSMutableDictionary *cachedInstances;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cachedInstances = [NSMutableDictionary dictionary];
  });
  return cachedInstances;
}

+ (FIRHeartbeatLogger *)getInstanceForID:(NSString *)ID {
  @synchronized(self) {
    if (self.cachedInstances[ID] && self.cachedInstances[ID].object) {
      // There is an existing instance to get.
      return [self.cachedInstances[ID] object];
    } else {
      FIRHeartbeatLogger *newInstance = [[FIRHeartbeatLogger alloc] initWithAppID:ID];
      self.cachedInstances[ID] = [FIRWeakContainer containerWithObject:newInstance];
      return newInstance;
    }
  }
}

- (void)dealloc {
  // Removes the instance if it was cached.
  [[self.class cachedInstances] removeObjectForKey:_appID];
}

+ (FIRHeartbeatLogger *)loggerForAppID:(NSString *)appID {
  return [self getInstanceForID:appID];
}

// MARK: - Flushing/Logging

- (void)log {
  NSString *userAgent = _userAgentProvider();
  [_heartbeatController log:userAgent];
}

- (FIRHeartbeatsPayload *)flushHeartbeatsIntoPayload {
  FIRHeartbeatsPayload *payload = [_heartbeatController flush];
  return payload;
}

- (FIRHeartbeatInfoCode)heartbeatCodeForToday {
  FIRHeartbeatsPayload *todaysHeartbeatPayload = [_heartbeatController flushHeartbeatFromToday];

  if ([todaysHeartbeatPayload isEmpty]) {
    return FIRHeartbeatInfoCodeNone;
  } else {
    return FIRHeartbeatInfoCodeGlobal;
  }
}

@end
