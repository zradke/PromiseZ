//
//  PromiseZ_Specs.m
//  PromiseZ
//
//  Created by Zachary Radke on 8/7/13.
//  Copyright (c) 2013 Zachary Radke. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "PromiseZ_Private.h"

SPEC_BEGIN(PromiseZ_Specs)

__block PromiseZ *promise;

beforeEach(^{
    promise = [PromiseZ new];
});

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

describe(@"resolving a handler block and a dependent promise", ^{
    __block PromiseZ *dependentPromise;
    __block id (^genericHandler)(id);
    __block NSString *handlerResult;
    beforeEach(^{
        dependentPromise = [PromiseZ new];
        handlerResult = @"Handler Result!";
        genericHandler = ^id(id value) {
            return handlerResult;
        };
    });
    
    context(@"when the parent promise is kept", ^{
        beforeEach(^{
            [promise keepWithResult:@"Parent Result"];
        });
        
        it(@"resolves the dependent promise with the handler's result", ^{
            [[[dependentPromise should] receive] resolveWithHandlerResult:handlerResult];
            [promise resolveHandlerBlock:genericHandler withDependentPromise:dependentPromise];
        });
        
        context(@"without a handler", ^{
            it(@"keeps the dependent promise with the parent's result", ^{
                [promise resolveHandlerBlock:nil withDependentPromise:dependentPromise];
                [[theValue([dependentPromise isKept]) should] beTrue];
                [[[dependentPromise result] should] equal:[promise result]];
            });
        });
        
        context(@"without a dependent promise", ^{
            __block BOOL handlerRun;
            beforeEach(^{
                handlerRun = NO;
                genericHandler = ^id(id value) {
                    handlerRun = YES;
                    return handlerResult;
                };
            });
            
            it(@"still executes the handler block", ^{
                [promise resolveHandlerBlock:genericHandler withDependentPromise:nil];
                [[theValue(handlerRun) should] beTrue];
            });
        });
        
        context(@"when an exception is thrown", ^{
            __block id (^brokenHandler)(id);
            beforeEach(^{
                brokenHandler = ^id(id value) {
                    NSArray *brokenArray = [NSArray array];
                    return [brokenArray objectAtIndex:1];
                };
            });
            
            it(@"breaks the dependent promise with an error", ^{
                [promise resolveHandlerBlock:brokenHandler withDependentPromise:dependentPromise];
                [[theValue([dependentPromise isBroken]) should] beTrue];
                [[dependentPromise result] shouldNotBeNil];
            });
        });
    });
    
    context(@"when the parent promise is broken", ^{
        beforeEach(^{
            [promise breakWithReason:[NSError errorWithDomain:PZErrorDomain code:1000 userInfo:nil]];
        });
        
        it(@"resolves the dependent promise with the handler's result", ^{
            [[[dependentPromise should] receive] resolveWithHandlerResult:handlerResult];
            [promise resolveHandlerBlock:genericHandler withDependentPromise:dependentPromise];
        });
        
        context(@"when there is no handler", ^{
            it(@"breaks the dependent promise with the parent's reason", ^{
                [promise resolveHandlerBlock:nil withDependentPromise:dependentPromise];
                [[theValue([dependentPromise isBroken]) should] beTrue];
                [[[dependentPromise result] should] equal:[promise result]];
            });
        });
        
        context(@"when the handler throws an error", ^{
            __block id(^brokenHandler)(id);
            beforeEach(^{
                brokenHandler = ^id(id value) {
                    return [[NSArray array] objectAtIndex:1];
                };
            });
            
            it(@"breaks the dependent promise with an error", ^{
                [promise resolveHandlerBlock:brokenHandler withDependentPromise:dependentPromise];
                [[theValue([dependentPromise isBroken]) should] beTrue];
                [[dependentPromise result] shouldNotBeNil];
            });
        });
    });
});

describe(@"resolving a promise with a handler's result", ^{
    context(@"if the recursive resolution count is too high", ^{
        beforeEach(^{
            [promise setRecursiveResolutionCount:PZMaximumRecursiveResolutionDepth+1];
            [promise resolveWithHandlerResult:nil];
        });
        
        it(@"breaks the promise with an error", ^{
            [[theValue([promise isBroken]) should] beTrue];
        });
    });
    
    context(@"if a promise is passed as the value", ^{
        __block PromiseZ *resultPromise;
        
        beforeEach(^{
            resultPromise = [PromiseZ new];
        });
        
        it(@"binds the promise to the result", ^{
            [[[promise should] receive] bindToPromise:resultPromise];
            [promise resolveWithHandlerResult:resultPromise];
        });
        
        context(@"if the promise itself is passed as the value", ^{
            beforeEach(^{
                [promise resolveWithHandlerResult:promise];
            });
            
            it(@"breaks the promise with an error", ^{
                [[theValue([promise isBroken]) should] beTrue];
            });
        });
    });
    
    context(@"if the result is PZThenable", ^{
        __block id mockThenable;
        __block PZOnKeptBlock thenableOnKept;
        __block PZOnBrokenBlock thenableOnBroken;
        
        beforeEach(^{
            mockThenable = [KWMock mockForProtocol:@protocol(PZThenable)];
        });
        
        it(@"uses the then method", ^{
            [[[mockThenable should] receive] thenOnKept:any() orOnBroken:any()];
            [promise resolveWithHandlerResult:mockThenable];
        });
        
        context(@"on thenable kept", ^{
            beforeEach(^{
                KWCaptureSpy *spy = [mockThenable captureArgument:@selector(thenOnKept:orOnBroken:) atIndex:0];
                [promise resolveWithHandlerResult:mockThenable];
                thenableOnKept = spy.argument;
            });
            
            it(@"increments the recursive resolution count", ^{
                [promise setRecursiveResolutionCount:0];
                [[promise stub] keepWithResult:any()];
                thenableOnKept(nil);
                [[theValue(promise.recursiveResolutionCount) should] equal:theValue(1)];                
            });
            
            it(@"recursively invokes the resolution method with the new value", ^{
                NSString *thenableResult = @"New Value";
                [[[promise should] receive] resolveWithHandlerResult:thenableResult];
                thenableOnKept(thenableResult);
            });
        });
        
        context(@"on thenable broken", ^{
            beforeEach(^{
                KWCaptureSpy *spy = [mockThenable captureArgument:@selector(thenOnKept:orOnBroken:) atIndex:1];
                [promise resolveWithHandlerResult:mockThenable];
                thenableOnBroken = spy.argument;
            });
            
            it(@"breaks the promise with the passed value", ^{
                NSError *error = [NSError errorWithDomain:PZErrorDomain code:1000 userInfo:nil];
                thenableOnBroken(error);
                [[theValue([promise isBroken]) should] beTrue];
                [[[promise result] should] equal:error];
            });
        });
    });
});


SPEC_END
