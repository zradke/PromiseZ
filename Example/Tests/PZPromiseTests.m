//
//  PZPromiseTests.m
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <KVOController/FBKVOController.h>
#import <PromiseZ/PZPromise.h>

@interface PZSpyThenable : NSObject <PZThenable>

@property (assign, nonatomic) NSInteger thenCalledCount;
@property (copy, nonatomic, readonly) PZOnKeptBlock onKept;
@property (copy, nonatomic, readonly) PZOnBrokenBlock onBroken;

@end

@implementation PZSpyThenable

- (instancetype)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _thenCalledCount = 0;
    
    return self;
}

- (id<PZThenable>)thenOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken
{
    _onKept = [onKept copy];
    _onBroken = [onBroken copy];
    
    self.thenCalledCount += 1;
    
    return nil;
}

@end

@interface PZOuroboros : NSObject <PZThenable>
@property (strong, nonatomic) NSOperationQueue *resolutionQueue;
@end

@implementation PZOuroboros

- (instancetype)init
{
    if (!((self = [super init])))
    {
        return nil;
    }
    
    _resolutionQueue = [NSOperationQueue new];
    
    return self;
}

- (id<PZThenable>)thenOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken
{
    [self.resolutionQueue addOperationWithBlock:^{
        if (onKept)
        {
            onKept(self);
        }
    }];
    
    return nil;
}

@end


@interface PZPromiseTests : XCTestCase

@end

@implementation PZPromiseTests

- (void)tearDown
{
    [self.KVOController unobserveAll];
    [super tearDown];
}


#pragma mark - Initializers

- (void)testInit
{
    PZPromise *promise = [PZPromise new];
    
    XCTAssertNotNil(promise);
    XCTAssertEqual(promise.state, PZPromiseStatePending);
    XCTAssertNil(promise.keptValue);
    XCTAssertNil(promise.brokenReason);
}

- (void)testInitWithKeptValue
{
    PZPromise *promise = [[PZPromise alloc] initWithKeptValue:@"A"];
    
    XCTAssertNotNil(promise);
    XCTAssertEqual(promise.state, PZPromiseStateKept);
    XCTAssertEqualObjects(promise.keptValue, @"A");
    XCTAssertNil(promise.brokenReason);
}

- (void)testInitWithBrokenReason
{
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:1000 userInfo:nil];
    PZPromise *promise = [[PZPromise alloc] initWithBrokenReason:error];
    
    XCTAssertNotNil(promise);
    XCTAssertEqual(promise.state, PZPromiseStateBroken);
    XCTAssertEqualObjects(promise.brokenReason, error);
    XCTAssertNil(promise.keptValue);
}


#pragma mark - Keeping and breaking

- (void)testKeepWithValue
{
    PZPromise *promise = [PZPromise new];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Promise should be kept"];
    [self.KVOController observe:promise keyPath:NSStringFromSelector(@selector(keptValue)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if ([promise.keptValue isEqual:@"A"])
        {
            [expectation fulfill];
        }
    }];
    
    [promise keepWithValue:@"A"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqual(promise.state, PZPromiseStateKept);
    XCTAssertEqualObjects(promise.keptValue, @"A");
    XCTAssertNil(promise.brokenReason);
}

- (void)testBreakWithReason
{
    PZPromise *promise = [PZPromise new];
    
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:1000 userInfo:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Promise should be broken"];
    [self.KVOController observe:promise keyPath:NSStringFromSelector(@selector(brokenReason)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if ([promise.brokenReason isEqual:error])
        {
            [expectation fulfill];
        }
    }];
    
    [promise breakWithReason:error];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqual(promise.state, PZPromiseStateBroken);
    XCTAssertEqualObjects(promise.brokenReason, error);
    XCTAssertNil(promise.keptValue);
}

#pragma mark - On-Kept

- (void)testThenOnKept
{
    XCTestExpectation *expectationA = [self expectationWithDescription:@"On-kept should be called"];
    __block BOOL onKeptExecuted = NO;
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:^id(id value) {
        onKeptExecuted = YES;
        [expectationA fulfill];
        return @"B";
    } onBroken:nil];
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateKept)
        {
            [expectationB fulfill];
        }
    }];
    
    [promiseA keepWithValue:@"A"];
    
    XCTAssertFalse(onKeptExecuted);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertTrue(onKeptExecuted);
    XCTAssertEqualObjects(promiseA.keptValue, @"A");
    XCTAssertEqualObjects(promiseB.keptValue, @"B");
}

- (void)testThenOnKeptReturnsPromiseKept
{
    XCTestExpectation *expectationA = [self expectationWithDescription:@"On-kept should be called"];
    __block BOOL onKeptExecuted = NO;
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [PZPromise new];
    PZPromise *promiseC = [promiseA thenOnKept:^id(id value) {
        onKeptExecuted = YES;
        [expectationA fulfill];
        return promiseB;
    } onBroken:nil];
    
    [promiseA keepWithValue:@"A"];
    
    XCTAssertFalse(onKeptExecuted);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertTrue(onKeptExecuted);
    
    XCTAssertEqual(promiseC.state, PZPromiseStatePending);
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseC keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseC.state == PZPromiseStateKept)
        {
            [expectationB fulfill];
        }
    }];
    
    [promiseC keepWithValue:@"C"];
    [promiseB keepWithValue:@"B"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseC.keptValue, @"B");
}

- (void)testThenOnKeptReturnsPromiseBroken
{
    XCTestExpectation *expectationA = [self expectationWithDescription:@"On-kept should be called"];
    __block BOOL onKeptExecuted = NO;
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [PZPromise new];
    PZPromise *promiseC = [promiseA thenOnKept:^id(id value) {
        onKeptExecuted = YES;
        [expectationA fulfill];
        return promiseB;
    } onBroken:nil];
    
    [promiseA keepWithValue:@"A"];
    
    XCTAssertFalse(onKeptExecuted);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertTrue(onKeptExecuted);
    
    XCTAssertEqual(promiseC.state, PZPromiseStatePending);
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseC keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseC.state == PZPromiseStateBroken)
        {
            [expectationB fulfill];
        }
    }];
    
    [promiseC keepWithValue:@"C"];
    
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    [promiseB breakWithReason:error];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseC.brokenReason, error);
}

- (void)testThenOnKeptThrowsException
{
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:^id(id value) {
        [NSException raise:NSInternalInconsistencyException format:@"Expected exception raised!"];
        return @"B";
    } onBroken:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectation fulfill];
        }
    }];
    
    [promiseA keepWithValue:@"A"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(promiseB.brokenReason);
}

- (void)testThenOnKeptReturnsSamePromise
{
    PZPromise *promiseA = [PZPromise new];
    __block PZPromise *promiseB = [promiseA thenOnKept:^id(id value) {
        return promiseB;
    } onBroken:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectation fulfill];
        }
    }];
    
    [promiseA keepWithValue:@"A"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(promiseB.brokenReason);
}

- (void)testThenOnKeptReturnsThenable
{
    PZSpyThenable *thenable = [PZSpyThenable new];
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:^id(id value) {
        return thenable;
    } onBroken:nil];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"Thenable should be asked to then"];
    [self.KVOController observe:thenable keyPath:NSStringFromSelector(@selector(thenCalledCount)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (thenable.thenCalledCount == 1)
        {
            [expectationA fulfill];
        }
    }];
    
    [promiseA keepWithValue:@"A"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(thenable.onKept);
    XCTAssertNotNil(thenable.onBroken);
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateKept)
        {
            [expectationB fulfill];
        }
    }];
    
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    
    thenable.onKept(@"B");
    thenable.onKept(@"C");
    thenable.onBroken(error);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseB.keptValue, @"B");
}

- (void)testThenOnKeptReturnsOuroboros
{
    PZOuroboros *ouroboros = [PZOuroboros new];
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:^id(id value) {
        return ouroboros;
    } onBroken:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectation fulfill];
        }
    }];
    
    [promiseA keepWithValue:@"A"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(promiseB.brokenReason);
}

- (void)testThenOnKeptWithoutBlock
{
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:nil onBroken:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateKept)
        {
            [expectation fulfill];
        }
    }];
    
    [promiseA keepWithValue:@"A"];
    
    XCTAssertEqual(promiseB.state, PZPromiseStatePending);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseB.keptValue, @"A");
}


#pragma mark - On-Broken

- (void)testThenOnBroken
{
    XCTestExpectation *expectationA = [self expectationWithDescription:@"On-broken should be called"];
    __block BOOL onBrokenExecuted = NO;
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:nil onBroken:^id(NSError *reason) {
        onBrokenExecuted = YES;
        [expectationA fulfill];
        return @"A";
    }];
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateKept)
        {
            [expectationB fulfill];
        }
    }];
    
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    [promiseA breakWithReason:error];
    
    XCTAssertFalse(onBrokenExecuted);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertTrue(onBrokenExecuted);
    XCTAssertEqualObjects(promiseA.brokenReason, error);
    XCTAssertEqualObjects(promiseB.keptValue, @"A");
}

- (void)testThenOnBrokenReturnsPromiseKept
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"On-broken should be called"];
    __block BOOL onBrokenExecuted = NO;
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [PZPromise new];
    PZPromise *promiseC = [promiseA thenOnKept:nil onBroken:^id(NSError *reason) {
        onBrokenExecuted = YES;
        [expectation fulfill];
        return promiseB;
    }];
    
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    [promiseA breakWithReason:error];
    
    XCTAssertFalse(onBrokenExecuted);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertTrue(onBrokenExecuted);
    XCTAssertEqualObjects(promiseA.brokenReason, error);
    XCTAssertEqual(promiseC.state, PZPromiseStatePending);
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseC keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseC.state == PZPromiseStateKept)
        {
            [expectationB fulfill];
        }
    }];
    
    [promiseC keepWithValue:@"C"];
    [promiseB keepWithValue:@"A"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseC.keptValue, @"A");
}

- (void)testThenOnBrokenReturnsPromiseBroken
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"On-broken should be called"];
    __block BOOL onBrokenExecuted = NO;
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [PZPromise new];
    PZPromise *promiseC = [promiseA thenOnKept:nil onBroken:^id(NSError *reason) {
        onBrokenExecuted = YES;
        [expectation fulfill];
        return promiseB;
    }];
    
    NSError *errorA = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    [promiseA breakWithReason:errorA];
    
    XCTAssertFalse(onBrokenExecuted);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertTrue(onBrokenExecuted);
    XCTAssertEqualObjects(promiseA.brokenReason, errorA);
    XCTAssertEqual(promiseC.state, PZPromiseStatePending);
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseC keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseC.state == PZPromiseStateBroken)
        {
            [expectationB fulfill];
        }
    }];
    
    [promiseC keepWithValue:@"C"];
    
    NSError *errorB = [NSError errorWithDomain:PZErrorDomain code:800 userInfo:nil];
    [promiseB breakWithReason:errorB];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseC.brokenReason, errorB);
}

- (void)testThenOnBrokenThrowsException
{
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:nil onBroken:^id(NSError *reason) {
        [NSException raise:NSInternalInconsistencyException format:@"Expected exception raised!"];
        return @"B";
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectation fulfill];
        }
    }];
    
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    [promiseA breakWithReason:error];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(promiseB.brokenReason);
    XCTAssertNotEqualObjects(promiseB.brokenReason, error);
}

- (void)testThenOnBrokenReturnsSamePromise
{
    PZPromise *promiseA = [PZPromise new];
    __block PZPromise *promiseB = [promiseA thenOnKept:nil onBroken:^id(NSError *reason) {
        return promiseB;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectation fulfill];
        }
    }];
    
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    [promiseA breakWithReason:error];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(promiseB.brokenReason);
    XCTAssertNotEqualObjects(promiseB.brokenReason, error);
}

- (void)testThenOnBrokenReturnsThenable
{
    PZSpyThenable *thenable = [PZSpyThenable new];
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:nil onBroken:^id(NSError *reason) {
        return thenable;
    }];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"The thennable should then."];
    [self.KVOController observe:thenable keyPath:NSStringFromSelector(@selector(thenCalledCount)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (thenable.thenCalledCount == 1)
        {
            [expectationA fulfill];
        }
    }];
    
    NSError *errorA = [NSError errorWithDomain:PZErrorDomain code:1000 userInfo:nil];
    [promiseA breakWithReason:errorA];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(thenable.onKept);
    XCTAssertNotNil(thenable.onBroken);
    
    XCTestExpectation *expectationB = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectationB fulfill];
        }
    }];
    
    NSError *errorB = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    NSError *errorC = [NSError errorWithDomain:PZErrorDomain code:800 userInfo:nil];
    
    thenable.onBroken(errorB);
    thenable.onBroken(errorC);
    thenable.onKept(@"B");
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseB.brokenReason, errorB);
}

- (void)testThenOnBrokenReturnsOuroboros
{
    PZOuroboros *ouroboros = [PZOuroboros new];
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:^id(id value) {
        return ouroboros;
    } onBroken:^id(NSError *reason) {
        return ouroboros;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectation fulfill];
        }
    }];
    
    [promiseA keepWithValue:@"A"];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertNotNil(promiseB.brokenReason);
}

- (void)testThenOnBrokenWithoutBlock
{
    PZPromise *promiseA = [PZPromise new];
    PZPromise *promiseB = [promiseA thenOnKept:nil onBroken:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Returned promise should resolve."];
    [self.KVOController observe:promiseB keyPath:NSStringFromSelector(@selector(state)) options:0 block:^(id observer, id object, NSDictionary *change) {
        if (promiseB.state == PZPromiseStateBroken)
        {
            [expectation fulfill];
        }
    }];
        
    NSError *error = [NSError errorWithDomain:PZErrorDomain code:900 userInfo:nil];
    [promiseA breakWithReason:error];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertEqualObjects(promiseA.brokenReason, error);
    XCTAssertEqualObjects(promiseB.brokenReason, error);
}

@end
