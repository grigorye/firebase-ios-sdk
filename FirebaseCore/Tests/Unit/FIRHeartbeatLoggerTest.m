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

#import <XCTest/XCTest.h>

@import HeartbeatLoggingTestUtils;

#import "FirebaseCore/Extension/FIRHeartbeatLogger.h"

@interface FIRHeartbeatLogger (Internal)
- (instancetype)initWithAppID:(NSString *)appID
            userAgentProvider:(NSString * (^)(void))userAgentProvider;
@end

@interface FIRHeartbeatLoggerTest : XCTestCase
@property(nonatomic) FIRHeartbeatLogger *heartbeatLogger;
@end

@implementation FIRHeartbeatLoggerTest

+ (NSString *)dummyAppID {
  return NSStringFromClass([self class]);
}

+ (NSString * (^)(void))dummyUserAgentProvider {
  return ^NSString * {
    return @"dummy_agent";
  };
}

+ (NSString *)formattedStringForDate:(NSDate *)date {
  return [[FIRHeartbeatLoggingTestUtils dateFormatter] stringFromDate:date];
}

- (void)setUp {
  _heartbeatLogger =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  [FIRHeartbeatLoggingTestUtils removeUnderlyingHeartbeatStorageContainersAndReturnError:nil];
}

- (void)tearDown {
  [FIRHeartbeatLoggingTestUtils removeUnderlyingHeartbeatStorageContainersAndReturnError:nil];
}

#pragma mark - Instance Management

- (void)testGettingInstance_WithSameAppID_ReturnsSameInstance {
  // Given
  FIRHeartbeatLogger *heartbeatLogger1 = [FIRHeartbeatLogger loggerForAppID:@"appID"];
  // When
  FIRHeartbeatLogger *heartbeatLogger2 = [FIRHeartbeatLogger loggerForAppID:@"appID"];
  // Then
  NSLog(@"");
  XCTAssertNotNil(heartbeatLogger1);
  XCTAssertNotNil(heartbeatLogger2);
  XCTAssert(heartbeatLogger1 == heartbeatLogger2, "Instances should reference the same object.");

  __auto_type __weak weakHeartbeatLogger1 = heartbeatLogger1;
  __auto_type __weak weakHeartbeatLogger2 = heartbeatLogger2;
  [self addTeardownBlock:^{
    XCTAssertNil(weakHeartbeatLogger1);
    XCTAssertNil(weakHeartbeatLogger2);
  }];
}

- (void)testGettingInstance_WithDifferentAppID_ReturnsDifferentInstances {
  // Given
  FIRHeartbeatLogger *heartbeatLogger1 = [FIRHeartbeatLogger loggerForAppID:@"appID_1"];
  // When
  FIRHeartbeatLogger *heartbeatLogger2 = [FIRHeartbeatLogger loggerForAppID:@"appID_2"];
  // Then
  XCTAssertNotNil(heartbeatLogger1);
  XCTAssertNotNil(heartbeatLogger2);
  XCTAssert(heartbeatLogger1 != heartbeatLogger2, "Instances should reference the same object.");

  __auto_type __weak weakHeartbeatLogger1 = heartbeatLogger1;
  __auto_type __weak weakHeartbeatLogger2 = heartbeatLogger2;
  [self addTeardownBlock:^{
    XCTAssertNil(weakHeartbeatLogger1);
    XCTAssertNil(weakHeartbeatLogger2);
  }];
}

- (void)testCachedInstancesCannotBeRetainedWeakly {
  // Given
  FIRHeartbeatLogger *strongHeartbeatLogger = [FIRHeartbeatLogger loggerForAppID:@"appID"];
  FIRHeartbeatLogger *__weak weakHeartbeatLogger = nil;
  @autoreleasepool {
    weakHeartbeatLogger = [FIRHeartbeatLogger loggerForAppID:@"appID"];
  }
  XCTAssertNotNil(strongHeartbeatLogger);
  XCTAssertNotNil(weakHeartbeatLogger);
  XCTAssert(strongHeartbeatLogger == weakHeartbeatLogger,
            "Instances should reference the same object.");
  // When
  strongHeartbeatLogger = nil;
  // Then
  XCTAssertNil(strongHeartbeatLogger);
  XCTAssertNil(weakHeartbeatLogger);
}

- (void)testCachedInstancesAreRemovedUponDeallocButCanBeRetainedStrongly {
  // Given
  FIRHeartbeatLogger *heartbeatLogger1 = [FIRHeartbeatLogger loggerForAppID:@"appID"];
  FIRHeartbeatLogger *heartbeatLogger2 = [FIRHeartbeatLogger loggerForAppID:@"appID"];
  FIRHeartbeatLogger *heartbeatLogger3 = [FIRHeartbeatLogger loggerForAppID:@"appID_1"];
  XCTAssertNotNil(heartbeatLogger1);
  XCTAssertNotNil(heartbeatLogger2);
  XCTAssert(heartbeatLogger1 == heartbeatLogger2, "Instances should reference the same object.");
  // When
  heartbeatLogger1 = nil;
  XCTAssertNil(heartbeatLogger1);
  XCTAssertNotNil(heartbeatLogger2);
  // Then
  heartbeatLogger2 = nil;
  XCTAssertNil(heartbeatLogger2);

  [self addTeardownBlock:^{
    FIRHeartbeatLogger *heartbeatLogger4 = [FIRHeartbeatLogger loggerForAppID:@"appID_1"];
    XCTAssertNotNil(heartbeatLogger3);
    XCTAssertNotNil(heartbeatLogger4);
    XCTAssert(heartbeatLogger3 == heartbeatLogger4, "Instances should reference the same object.");
  }];
}

- (void)testGetInstanceStressTest {
  // Given
  NSMutableArray *instances = [NSMutableArray array];

  // When
  NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
  for (NSInteger i = 0; i < 1000; i++) {
    XCTestExpectation *expectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"count: %@", @(i)]];
    [expectations addObject:expectation];
    dispatch_async(dispatch_get_main_queue(), ^{
      [instances addObject:[FIRHeartbeatLogger loggerForAppID:@"appID"]];
      [expectation fulfill];
    });
  }
  [self waitForExpectations:expectations timeout:3.0];

  // Then
  XCTAssertEqual([[NSSet setWithArray:instances] count], 1);
}

#pragma mark - Logging/Flushing

- (void)testDoNotLogMoreThanOnceToday {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger log];
  [heartbeatLogger log];

  // Then
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];

  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
}

- (void)testDoNotLogMoreThanOnceToday_AfterFlushing {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger log];
  FIRHeartbeatsPayload *firstHeartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  [heartbeatLogger log];
  FIRHeartbeatsPayload *secondHeartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(firstHeartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];

  [self assertHeartbeatsPayloadIsEmpty:secondHeartbeatsPayload];
}

- (void)testFlushing_UsingV1API_WhenHeartbeatsAreStored_ReturnsFIRHeartbeatInfoCodeGlobal {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  [heartbeatLogger log];
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeGlobal);
}

- (void)testFlushing_UsingV1API_WhenNoHeartbeatsAreStored_ReturnsFIRHeartbeatInfoCodeNone {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeNone);
}

- (void)testFlushing_UsingV2API_WhenHeartbeatsAreStored_ReturnsNonEmptyPayload {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger log];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
}

- (void)testFlushing_UsingV2API_WhenNoHeartbeatsAreStored_ReturnsEmptyPayload {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

- (void)testLogAndFlushUsingV1API_AndThenFlushAgainUsingV2API_FlushesHeartbeatInTheFirstFlush {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  [heartbeatLogger log];
  // When
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeGlobal);
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

- (void)testLogAndFlushUsingV2API_AndThenFlushAgainUsingV1API_FlushesHeartbeatInTheFirstFlush {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  [heartbeatLogger log];
  // When
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeNone);
}

- (void)testHeartbeatLoggersWithSameIDShareTheSameStorage {
  // Given
  FIRHeartbeatLogger *heartbeatLogger1 =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  FIRHeartbeatLogger *heartbeatLogger2 =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger1 log];
  // Then
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger2 flushHeartbeatsIntoPayload];
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
  [self assertHeartbeatLoggerFlushesEmptyPayload:heartbeatLogger1];
}

- (void)testLoggingAHeartbeatDoesNotDependOnUserAgent {
  // Given
  __block NSString *dummyUserAgent = @"dummy_agent_1";
  __auto_type dummyUserAgentProvider = ^NSString * {
    return dummyUserAgent;
  };
  FIRHeartbeatLogger *heartbeatLogger =
      [[FIRHeartbeatLogger alloc] initWithAppID:@"testLoggingAHeartbeatDoesNotDependOnUserAgent"
                              userAgentProvider:dummyUserAgentProvider];
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  [heartbeatLogger log];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // When
  dummyUserAgent = @"dummy_agent_2";
  [heartbeatLogger log];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent_1", @"dates" : @[ expectedDate ]} ]
              }];
  [self assertHeartbeatLoggerFlushesEmptyPayload:heartbeatLogger];
}

#pragma mark - Assertions

- (void)assertEncodedPayloadHeader:(NSString *)payloadHeader
              isEqualToPayloadJSON:(NSDictionary *)payloadJSON {
  NSData *payloadJSONData = [NSJSONSerialization dataWithJSONObject:payloadJSON
                                                            options:NSJSONWritingPrettyPrinted
                                                              error:nil];
  NSString *payloadJSONString = [[NSString alloc] initWithData:payloadJSONData
                                                      encoding:NSUTF8StringEncoding];
  [FIRHeartbeatLoggingTestUtils assertEncodedPayloadString:payloadHeader
                                    isEqualToLiteralString:payloadJSONString
                                                 withError:nil];
}

- (void)assertHeartbeatsPayloadIsEmpty:(FIRHeartbeatsPayload *)heartbeatsPayload {
  XCTAssertNil(FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload));
}

- (void)assertHeartbeatLoggerFlushesEmptyPayload:(FIRHeartbeatLogger *)heartbeatLogger {
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

@end
