//
//  PromiseZ_Specs.m
//  PromiseZ
//
//  Created by Zachary Radke on 8/7/13.
//  Copyright (c) 2013 Zachary Radke. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "PromiseZ.h"

// Expose private methods and properties
@interface PromiseZ ()
@property (strong, nonatomic) NSOperationQueue *handlerQueue;
@property (assign, nonatomic) NSInteger recursiveResolutionCount;
@property (strong, nonatomic) NSRecursiveLock *lock;

@property (strong, nonatomic, readwrite) id result;
@property (assign, nonatomic, readwrite) PZPromiseState state;
@property (weak, nonatomic, readwrite) PromiseZ *bindingPromise;

- (void)bindToPromise:(PromiseZ *)promise;
- (void)resolveWithHandlerResult:(id)result;
- (void)resolveHandlerBlock:(id (^)(id))handlerBlock withDependentPromise:(PromiseZ *)dependentPromise;
- (instancetype)enqueueOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken returnPromise:(BOOL)shouldReturnPromise;
@end


SPEC_BEGIN(PromiseZ_Specs)

__block PromiseZ *promise;
__block NSString *result;
__block NSError *reason;

beforeEach(^{
    promise = [PromiseZ new];
    result = @"Kept!";
    reason = [NSError errorWithDomain:PZErrorDomain code:-100 userInfo:nil];
});

#pragma mark - Promises/A+ spec tests

describe(@"promise states", ^{
    context(@"when pending", ^{
        specify(^{
            [[theValue([promise isPending]) should] beTrue];
            [[theValue([promise isKept]) should] beFalse];
            [[theValue([promise isBroken]) should] beFalse];
        });
        
        it(@"can be kept", ^{
            [promise keepWithResult:result];
            [[theValue([promise isKept]) should] beTrue];
        });
        
        it(@"can be broken", ^{
            [promise breakWithReason:reason];
            [[theValue([promise isBroken]) should] beTrue];
        });
    });
    
    context(@"when kept", ^{
        beforeEach(^{
            [promise keepWithResult:result];
        });
        
        specify(^{
            [[theValue([promise isKept]) should] beTrue];
            [[theValue([promise isBroken]) should] beFalse];
            [[theValue([promise isPending]) should] beFalse];
            [[[promise result] should] equal:result];
        });
        
        it(@"cannot transition to broken", ^{
            [promise breakWithReason:reason];
            [[theValue([promise isBroken]) shouldNot] beTrue];
        });
        
        
        it(@"cannot change its result", ^{
            NSString *newResult = @"New Result";
            [promise keepWithResult:newResult];
            [[[promise result] shouldNot] equal:newResult];
        });
    });
    
    context(@"when broken", ^{
        beforeEach(^{
            [promise breakWithReason:reason];
        });
        
        specify(^{
            [[theValue([promise isBroken]) should] beTrue];
            [[theValue([promise isKept]) should] beFalse];
            [[theValue([promise isPending]) should] beFalse];
            [[[promise result] should] equal:reason];
        });
        
        it(@"cannot transition to kept", ^{
            [promise keepWithResult:result];
            [[theValue([promise isKept]) shouldNot] beTrue];
        });
        
        it(@"cannot change its result", ^{
            NSError *newError = [NSError errorWithDomain:PZErrorDomain code:-110 userInfo:nil];
            [promise breakWithReason:newError];
            [[[promise result] shouldNot] equal:newError];
        });
    });
});

describe(@"the then method", ^{
    specify(^{
        [[theValue([promise respondsToSelector:@selector(thenOnKept:orOnBroken:)]) should] beTrue];
    });
    
    context(@"handler blocks are optional", ^{
        it(@"does not break without an onKept block", ^{
            [[theBlock(^{
                [promise thenOnKept:nil orOnBroken:^id(NSError *reason) {
                    return nil;
                }];
                [promise keepWithResult:result];
            }) shouldNotEventually] raise];
        });
        
        it(@"does not break without an onBroken block", ^{
            [[theBlock(^{
                [promise thenOnKept:^id(id value) {
                    return nil;
                } orOnBroken:nil];
                [promise breakWithReason:reason];
            }) shouldNotEventually] raise];
        });
    });
    
    context(@"with an onKept block", ^{
        it(@"executes the block with the fulfilled result", ^{
            __block BOOL fulfilled = NO;
            [promise thenOnKept:^id(id value) {
                fulfilled = [value isEqual:result];
                return nil;
            } orOnBroken:nil];
            [promise keepWithResult:result];
            [[expectFutureValue(theValue(fulfilled)) shouldEventually] beTrue];
        });
        
        it(@"does not execute the block before the promise is fulfilled", ^{
            __block BOOL fulfilled = NO;
            [promise thenOnKept:^id(id value) {
                fulfilled = [promise isKept];
                return nil;
            } orOnBroken:nil];
            [promise keepWithResult:result];
            [[expectFutureValue(theValue(fulfilled)) shouldEventually] beTrue];
        });
        
        it(@"does not execute the block more than once", ^{
            __block NSInteger timesExecuted = 0;
            [promise thenOnKept:^id(id value) {
                timesExecuted += 1;
                return nil;
            } orOnBroken:nil];
            [promise keepWithResult:result];
            [[expectFutureValue(theValue(timesExecuted)) shouldNotEventually] beGreaterThan:theValue(1)];
        });
    });
    
    context(@"with an onBroken block", ^{
        it(@"executes the block with the broken reason", ^{
            __block BOOL fulfilled = NO;
            [promise thenOnKept:nil orOnBroken:^id(NSError *returnedReason) {
                fulfilled = [returnedReason isEqual:reason];
                return nil;
            }];
            [promise breakWithReason:reason];
            [[expectFutureValue(theValue(fulfilled)) shouldEventually] beTrue];
        });
        
        it(@"does not execute the block before the promise is broken", ^{
            __block BOOL fulfilled = NO;
            [promise thenOnKept:nil orOnBroken:^id(NSError *returnedReason) {
                fulfilled = [promise isBroken];
                return nil;
            }];
            [promise breakWithReason:reason];
            [[expectFutureValue(theValue(fulfilled)) shouldEventually] beTrue];
        });
        
        it(@"does not execute the block more than once", ^{
            __block NSInteger timesExecuted = 0;
            [promise thenOnKept:nil orOnBroken:^id(NSError *reason) {
                timesExecuted += 1;
                return nil;
            }];
            [promise breakWithReason:reason];
            [[expectFutureValue(theValue(timesExecuted)) shouldNotEventually] beGreaterThan:theValue(1)];
        });
    });
    
    it(@"returns before the onKept block executes", ^{
        [promise keepWithResult:result];
        __block BOOL blockInvoked = NO;
        [promise thenOnKept:^id(id value) {
            blockInvoked = YES;
            return nil;
        } orOnBroken:nil];
        [[theValue(blockInvoked) should] beFalse];
    });
    
    it(@"returns before the onBroken block executes", ^{
        [promise breakWithReason:reason];
        __block BOOL blockInvoked = NO;
        [promise thenOnKept:nil orOnBroken:^id(NSError *error) {
            blockInvoked = YES;
            return nil;
        }];
        [[theValue(blockInvoked) should] beFalse];
    });
    
    context(@"calling multiple times on the same instance", ^{
        it(@"executes onKept blocks in the order they were added", ^{
            __block BOOL firstInvoked = NO;
            __block BOOL secondInvoked = NO;
            
            [promise thenOnKept:^id(id value) {
                if (!secondInvoked) {
                    firstInvoked = YES;
                }
                return nil;
            } orOnBroken:nil];
            
            [promise thenOnKept:^id(id value) {
                if (firstInvoked) {
                    secondInvoked = YES;
                }
                return nil;
            } orOnBroken:nil];
            
            [promise keepWithResult:result];
            [[expectFutureValue(theValue(firstInvoked && secondInvoked)) shouldEventually] beTrue];
        });
        
        it(@"executes onBroken blocks in the order they were added", ^{
            __block BOOL firstInvoked = NO;
            __block BOOL secondInvoked = NO;
            
            [promise thenOnKept:nil orOnBroken:^id(NSError *error) {
                if (!secondInvoked) {
                    firstInvoked = YES;
                }
                return nil;
            }];
            
            [promise thenOnKept:nil orOnBroken:^id(NSError *error) {
                if (firstInvoked) {
                    secondInvoked = YES;
                }
                return nil;
            }];
            
            [promise breakWithReason:reason];
            [[expectFutureValue(theValue(firstInvoked && secondInvoked)) shouldEventually] beTrue];
        });
    });
    
    context(@"returned promise", ^{
        specify(^{
            id result = [promise thenOnKept:nil orOnBroken:nil];
            [[result shouldNot] beNil];
            [[theValue([result isKindOfClass:[promise class]]) should] beTrue];
        });
        
        it(@"resolves onKept block return values", ^{
            NSString *handlerResponse = @"Handler return!";
            PromiseZ *newPromise = [promise thenOnKept:^id(id value) {
                return handlerResponse;
            } orOnBroken:nil];
            [[[newPromise shouldEventually] receive] resolveWithHandlerResult:handlerResponse];
            [promise keepWithResult:result];
        });
        
        it(@"resolves onBroken block return values", ^{
            NSString *handlerResponse = @"Handler return!";
            PromiseZ *newPromise = [promise thenOnKept:nil orOnBroken:^id(NSError *error) {
                return handlerResponse;
            }];
            [[[newPromise shouldEventually] receive] resolveWithHandlerResult:handlerResponse];
            [promise breakWithReason:reason];
        });
        
        it(@"is rejected when onKept throws an exception", ^{
            PromiseZ *newPromise = [promise thenOnKept:^id(id value) {
                return [[NSArray array] objectAtIndex:1];
            } orOnBroken:nil];
            [promise keepWithResult:result];
            [[expectFutureValue(theValue([newPromise isBroken])) shouldEventually] beTrue];
            [[expectFutureValue([newPromise result]) shouldNotEventually] equal:result];
            
        });
        
        it(@"is rejected when onBroken throws an exception", ^{
            PromiseZ *newPromise = [promise thenOnKept:nil orOnBroken:^id(NSError *error) {
                return [[NSArray array] objectAtIndex:1];
            }];
            [promise breakWithReason:reason];
            [[expectFutureValue(theValue([newPromise isBroken])) shouldEventually] beTrue];
            [[expectFutureValue([newPromise result]) shouldNotEventually] equal:reason];
        });
        
        it(@"is kept without an onKept block when the main promise is kept", ^{
            PromiseZ *newPromise = [promise thenOnKept:nil orOnBroken:nil];
            [promise keepWithResult:result];
            [[expectFutureValue(theValue([newPromise isKept])) shouldEventually] beTrue];
            [[expectFutureValue([newPromise result]) shouldEventually] equal:result];
        });
        
        it(@"is broken without an onBroken block when the main promise is broken", ^{
            PromiseZ *newPromise = [promise thenOnKept:nil orOnBroken:nil];
            [promise breakWithReason:reason];
            [[expectFutureValue(theValue([newPromise isBroken])) shouldEventually] beTrue];
            [[expectFutureValue([newPromise result]) shouldEventually] equal:reason];
        });
    });
});

describe(@"promise resolution procedure", ^{
    it(@"is broken when trying to resolve itself", ^{
        [[[promise should] receive] breakWithReason:any()];
        [promise resolveWithHandlerResult:promise];
    });
    
    context(@"when the result is a PromiseZ", ^{
        __block PromiseZ *newPromise;
        beforeEach(^{
            newPromise = [PromiseZ new];
            [promise resolveWithHandlerResult:newPromise];
        });
        
        it(@"stays pending when the result is pending", ^{
            [[theValue([newPromise isPending]) should] beTrue];
            [[theValue([promise isPending]) should] beTrue];
        });
        
        it(@"is kept when the result is kept", ^{
            [newPromise keepWithResult:result];
            [[expectFutureValue(theValue([promise isKept])) shouldEventually] beTrue];
            [[expectFutureValue([promise result]) shouldEventually] equal:result];
        });
        
        it(@"is broken when the result is broken", ^{
            [newPromise breakWithReason:reason];
            [[expectFutureValue(theValue([promise isBroken])) shouldEventually] beTrue];
            [[expectFutureValue([promise result]) shouldEventually] equal:reason];
        });
    });
    
    context(@"when the result is thenable", ^{
        __block id thenable;
        __block PZOnKeptBlock onKept;
        __block PZOnBrokenBlock onBroken;
        beforeEach(^{
            thenable = [KWMock nullMockForProtocol:@protocol(PZThenable)];
            KWCaptureSpy *onKeptSpy = [thenable captureArgument:@selector(thenOnKept:orOnBroken:) atIndex:0];
            KWCaptureSpy *onBrokenSpy = [thenable captureArgument:@selector(thenOnKept:orOnBroken:) atIndex:1];
            [promise resolveWithHandlerResult:thenable];
            onKept = onKeptSpy.argument;
            onBroken = onBrokenSpy.argument;
        });
        
        it(@"recurses when the onKept block is executed", ^{
            [[[promise should] receive] resolveWithHandlerResult:result];
            onKept(result);
        });
        
        it(@"is broken when the onBroken block is executed", ^{
            [[[promise should] receive] breakWithReason:reason];
            onBroken(reason);
        });
        
        it(@"responds to the first handler execution", ^{
            [[[promise should] receive] resolveWithHandlerResult:result];
            [[[promise shouldNot] receive] breakWithReason:reason];
            onKept(result);
            onBroken(reason);
        });
        
        it(@"ignores multiple executions of onKept", ^{
            NSString *newResult = @"New result";
            [[[promise should] receive] resolveWithHandlerResult:result];
            [[[promise shouldNot] receive] resolveWithHandlerResult:newResult];
            onKept(result);
            onKept(newResult);
        });
        
        it(@"ignores multiple executions of onBroken", ^{
            NSError *newError = [NSError errorWithDomain:PZErrorDomain code:-110 userInfo:nil];
            [[[promise should] receive] breakWithReason:reason];
            [[[promise shouldNot] receive] breakWithReason:newError];
            onBroken(reason);
            onBroken(newError);
        });
        
        it(@"is rejected when recursion seems infinite", ^{
            [[[promise should] receive] breakWithReason:any()];
            [promise setRecursiveResolutionCount:PZMaximumRecursiveResolutionDepth];
            onKept(nil);
        });
    });
    
    it(@"is kept with other results", ^{
        [[[promise should] receive] keepWithResult:result];
        [promise resolveWithHandlerResult:result];
    });
});


#pragma mark - Implementation detail tests

describe(@"creating a promise", ^{
    it(@"not be nil", ^{
        [promise shouldNotBeNil];
    });
    
    it(@"sets up the handler queue", ^{
        [promise.handlerQueue shouldNotBeNil];
        [[theValue(promise.handlerQueue.maxConcurrentOperationCount) should] equal:theValue(1)];
        [[theValue(promise.handlerQueue.isSuspended) should] beTrue];
    });
    
    it(@"is pending", ^{
        [[theValue(promise.state) should] equal:theValue(PZPromiseStatePending)];
    });
});

describe(@"keeping a promise", ^{
    __block id result;
    
    beforeEach(^{
        result = @"Awaited result!";
    });
    
    context(@"when the promise is not bound", ^{
        beforeEach(^{
            [promise setRecursiveResolutionCount:10];
            [promise keepWithResult:result];
        });
        
        it(@"sets the promise's result", ^{
            [[[promise result] should] equal:result];
        });
        
        it(@"sets the state to kept", ^{
            [[theValue([promise state]) should] equal:theValue(PZPromiseStateKept)];
        });
        
        it(@"starts the handler queue to process enqueued blocks", ^{
            [[theValue([[promise handlerQueue] isSuspended]) should] beFalse];
        });
        
        it(@"resets the recursive resolution counter", ^{
            [[theValue([promise recursiveResolutionCount]) should] equal:theValue(0)];
        });
    });

    context(@"when the promise is bound", ^{
        __block PromiseZ *bindingPromise;
        beforeEach(^{
            bindingPromise = [PromiseZ new];
            [promise bindToPromise:bindingPromise];
            [promise keepWithResult:result];
        });
        
        it(@"does not change the result", ^{
            [[[promise result] shouldNot] equal:result];
        });
        
        it(@"does not change the state", ^{
            [[theValue([promise state]) shouldNot] equal:theValue(PZPromiseStateKept)];
        });
    });
});

describe(@"breaking a promise", ^{
    __block NSError *error;
    
    beforeEach(^{
        error = [NSError errorWithDomain:@"com.zachradke.TestDomain" code:1000 userInfo:nil];
    });
    
    context(@"when the promise is not bound", ^{
        beforeEach(^{
             [promise breakWithReason:error];
        });
        
        it(@"sets the promise's result", ^{
            [[[promise result] should] equal:error];
        });
        
        it(@"sets the state to broken", ^{
            [[theValue([promise state]) should] equal:theValue(PZPromiseStateBroken)];
        });
        
        it(@"starts the handler queue to process enqueued blocks", ^{
            [[theValue([[promise handlerQueue] isSuspended]) should] beFalse];
        });
    });
    
    context(@"when the promise is bound", ^{
        __block PromiseZ *bindingPromise;
        beforeEach(^{
            bindingPromise = [PromiseZ new];
            [promise bindToPromise:bindingPromise];
            [promise breakWithReason:error];
        });
        
        it(@"does not change the result", ^{
            [[[promise result] shouldNot] equal:error];
        });
        
        it(@"does not change the state", ^{
            [[theValue([promise state]) shouldNot] equal:theValue(PZPromiseStateBroken)];
        });
    });
});

describe(@"binding a promise to another promise", ^{
    __block PromiseZ *bindingPromise;
    beforeEach(^{
        bindingPromise = [PromiseZ new];
        [promise bindToPromise:bindingPromise];
    });
    
    it(@"sets the binding promise", ^{
        [[[promise bindingPromise] should] equal:bindingPromise];
    });
    
    context(@"when it is already bound", ^{
        __block PromiseZ *newBindingPromise;
        beforeEach(^{
            newBindingPromise = [PromiseZ new];
            [promise bindToPromise:newBindingPromise];
        });
        
        it(@"does not change the bound promise", ^{
            [[[promise bindingPromise] shouldNot] equal:newBindingPromise];
        });
    });
    
    context(@"when the binding promise is kept", ^{
        __block NSString *result;
        
        beforeEach(^{
            result = @"Result";
            [bindingPromise keepWithResult:result];
        });
        
        it(@"keeps the bound promise", ^{
            [[expectFutureValue(theValue([promise state])) shouldEventually] equal:theValue(PZPromiseStateKept)];
        });
        
        it(@"sets the result on the bound promise", ^{
            [[expectFutureValue([promise result]) shouldEventually] equal:result];
        });
    });
    
    context(@"when the binding promise is broken", ^{
        __block NSError *error;
        
        beforeEach(^{
            error = [NSError errorWithDomain:PZErrorDomain code:1000 userInfo:nil];
            [bindingPromise breakWithReason:error];
        });
        
        it(@"breaks the bound promise", ^{
            [[expectFutureValue(theValue([promise state])) shouldEventually] equal:theValue(PZPromiseStateBroken)];
        });
        
        it(@"sets the result on the bound promise", ^{
            [[expectFutureValue([promise result]) shouldEventually] equal:error];
        });
    });
});

SPEC_END
