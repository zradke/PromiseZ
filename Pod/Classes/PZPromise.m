//
//  PZPromise.m
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "PZPromise.h"
#import <libkern/OSAtomic.h>

NSInteger const PZMaximumResolutionRecursionDepth = 30;

NSString *const PZErrorDomain = @"com.zachradke.promiseZ.errorDomain";

@interface _PZResolutionOperation : NSOperation

- (instancetype)initWithPromise:(PZPromise *)promise onKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken NS_DESIGNATED_INITIALIZER;

@property (weak, nonatomic, readonly) PZPromise *promise;
@property (copy, nonatomic, readonly) PZOnKeptBlock onKept;
@property (copy, nonatomic, readonly) PZOnBrokenBlock onBroken;

// These properties are atomic and readwrite because they can be changed from multiple threads during promise resolution
@property (strong, atomic) id<PZThenable> retainedThenable;
@property (assign, atomic) NSUInteger resolutionCount;

@end


#pragma mark - PZPromise

@interface PZPromise ()
{
    OSSpinLock _spinLock;
}

@property (strong, nonatomic, readonly) NSOperationQueue *resolutionQueue;
@property (strong, nonatomic, readonly) PZPromise *bindingPromise;

@end

@implementation PZPromise
@synthesize state = _state;
@synthesize keptValue = _keptValue;
@synthesize brokenReason = _brokenReason;
@synthesize bindingPromise = _bindingPromise;

#pragma mark Creating promises

- (instancetype)init
{
    if ((self = [super init]))
    {
        _state = PZPromiseStatePending;
        
        // The spinlock will enforce thread safety for our properties
        _spinLock = OS_SPINLOCK_INIT;
        
        // The resolution queue is how we'll stack up thenOnKept:onBroken: blocks to be resolved later.
        _resolutionQueue = [NSOperationQueue new];
        _resolutionQueue.maxConcurrentOperationCount = 1;
        
        // The resolution queue must stay suspended until the promise is resolved or broken.
        [_resolutionQueue setSuspended:YES];
    }
    
    return self;
}

- (instancetype)initWithKeptValue:(id)keptValue
{
    if ((self = [self init]))
    {
        _state = PZPromiseStateKept;
        _keptValue = keptValue;
        _resolutionQueue.suspended = NO;
    }
    
    return self;
}

- (instancetype)initWithBrokenReason:(NSError *)brokenReason
{
    if ((self = [self init]))
    {
        _state = PZPromiseStateBroken;
        _brokenReason = brokenReason;
        _resolutionQueue.suspended = NO;
    }
    
    return self;
}

- (instancetype)initWithBindingPromise:(PZPromise *)bindingPromise;
{
    if (!(self = [self init]))
    {
        return nil;
    }
    
    _bindingPromise = bindingPromise;
    
    return self;
}

- (void)dealloc
{
    [_resolutionQueue cancelAllOperations];
    
    // As per the NSOperationQueue documentation, a suspended queue never clears out its operations even when cancelled, so we un-suspend the queue just in case here.
    _resolutionQueue.suspended = NO;
}


#pragma mark Keeping and breaking promises

- (BOOL)keepWithValue:(id)value
{
    return [self _transitionToState:PZPromiseStateKept valueOrReason:value isResolved:NO];
}

- (BOOL)breakWithReason:(NSError *)reason
{
    return [self _transitionToState:PZPromiseStateBroken valueOrReason:reason isResolved:NO];
}


#pragma mark NSObject

- (NSString *)description
{
    return [self descriptionWithLocale:[NSLocale currentLocale] indent:0];
}

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level
{
    NSString *padding = [@"" stringByPaddingToLength:level withString:@"\t" startingAtIndex:0];
    NSMutableString *mutableDescription = [NSMutableString stringWithFormat:@"%@<%@:%p>", padding, [self class], self];
    
    switch (self.state)
    {
        case PZPromiseStatePending:
        {
            [mutableDescription appendString:@" state:PZPromiseStatePending"];
            
            if (self.bindingPromise)
            {
                [mutableDescription appendFormat:@"\n%@", [self.bindingPromise descriptionWithLocale:locale indent:level+1]];
            }
            break;
        }
        case PZPromiseStateKept:
        {
            [mutableDescription appendFormat:@" state:PZPromiseStateKept, keptValue:%@", self.keptValue];
            break;
        }
        case PZPromiseStateBroken:
        {
            [mutableDescription appendFormat:@" state:PZPromiseStateBroken, brokenReason:%@", self.brokenReason];
            break;
        }
        default:
            break;
    }
    
    return [mutableDescription copy];
}


#pragma mark PZThenable

- (instancetype)thenOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken
{
    PZPromise *returnPromise;
    
    OSSpinLockLock(&_spinLock);
    
    if (self.state == PZPromiseStateKept && !onKept)
    {
        returnPromise = [[[self class] alloc] initWithKeptValue:self.keptValue];
    }
    else if (self.state == PZPromiseStateBroken && !onBroken)
    {
        returnPromise = [[[self class] alloc] initWithBrokenReason:self.brokenReason];
    }
    else
    {
        returnPromise = [[[self class] alloc] initWithBindingPromise:self];
        
        _PZResolutionOperation *operation = [[_PZResolutionOperation alloc] initWithPromise:returnPromise onKept:onKept onBroken:onBroken];
        [self.resolutionQueue addOperation:operation];
    }
    
    OSSpinLockUnlock(&_spinLock);
    
    return returnPromise;
}


#pragma mark Private

- (BOOL)_transitionToState:(PZPromiseState)state valueOrReason:(id)valueOrReason isResolved:(BOOL)isResolved
{
    NSAssert(state != PZPromiseStatePending, @"Cannot transition promise (%@) to pending state.", self);
    
    OSSpinLockLock(&_spinLock);
    
    // If a promise isn't pending it cannot be changed. Also, if a promise is being resolved (i.e. it was created via the -initWithBindingPromise: method) then it cannot be resolved manually unless isResolved is YES.
    if (self.state != PZPromiseStatePending || (self.bindingPromise != nil && !isResolved))
    {
        OSSpinLockUnlock(&_spinLock);
        return NO;
    }
    OSSpinLockUnlock(&_spinLock);
    
    NSString *changedValueKeyPath;
    if (state == PZPromiseStateKept)
    {
        changedValueKeyPath = NSStringFromSelector(@selector(keptValue));
    }
    else
    {
        changedValueKeyPath = NSStringFromSelector(@selector(brokenReason));
    }
    
    // The KVC notifications must be sent outside of our spin lock or else observers could accidentally cause a deadlock by invoking -thenOnKept:onBroken: or this method again.
    [self willChangeValueForKey:NSStringFromSelector(@selector(state))];
    [self willChangeValueForKey:changedValueKeyPath];
    
    OSSpinLockLock(&_spinLock);
    
    _state = state;
    _bindingPromise = nil;
    
    if (state == PZPromiseStateKept)
    {
        _keptValue = valueOrReason;
    }
    else
    {
        _brokenReason = valueOrReason;
    }
    
    OSSpinLockUnlock(&_spinLock);
    
    [self didChangeValueForKey:changedValueKeyPath];
    [self didChangeValueForKey:NSStringFromSelector(@selector(state))];
    
    // We resume our resolution queue which will allow the _PZResolutionOperations to commence. This must be done asynchronously to ensure that resolution happens in at least the next runloop
    dispatch_async(dispatch_get_main_queue(), ^{
        self.resolutionQueue.suspended = NO;
    });
    
    return YES;
}

@end


#pragma mark - _PZResolutionOperation

@implementation _PZResolutionOperation

- (instancetype)initWithPromise:(PZPromise *)promise onKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken
{
    NSParameterAssert(promise);
    
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _promise = promise;
    _onKept = [onKept copy];
    _onBroken = [onBroken copy];
    _resolutionCount = 0;
    
    return self;
}

- (void)main
{
    PZPromise *promise = self.promise;
    if (self.isCancelled || !promise)
    {
        // We nil out the blocks so any potential retain cycles are broken.
        _onKept = nil;
        _onBroken = nil;
        return;
    }
    
    PZPromise *bindingPromise = promise.bindingPromise;
    PZPromiseState bindingPromiseState = bindingPromise.state;
    
    if (bindingPromiseState == PZPromiseStatePending)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Internal promise inconsistency error.",
                                   NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"The promise (<%@:%p>) started resolving before being kept or broken.", [promise class], promise]};
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZInternalError userInfo:userInfo];
        
        // As per the spec, if a promise attempts to resolve before it can, it breaks both the returned promise and the binding promise.
        [promise _transitionToState:PZPromiseStateBroken valueOrReason:error isResolved:YES];
        [bindingPromise _transitionToState:PZPromiseStateBroken valueOrReason:error isResolved:YES];
        
        _onKept = nil;
        _onBroken = nil;
    }
    else if ((bindingPromiseState == PZPromiseStateKept && self.onKept) || (bindingPromiseState == PZPromiseStateBroken && self.onBroken))
    {
        @try
        {
            id blockResult;
            if (bindingPromiseState == PZPromiseStateKept)
            {
                blockResult = self.onKept(bindingPromise.keptValue);
            }
            else
            {
                blockResult = self.onBroken(bindingPromise.brokenReason);
            }
            
            // Once we've executed the blocks, we no longer need them
            _onKept = nil;
            _onBroken = nil;
            
            [self _resolvePromiseWithBlockResult:blockResult];
        }
        @catch (NSException *exception)
        {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unexepected exception raised while resolving promise (<%@:%p>).", [promise class], promise],
                                       NSLocalizedFailureReasonErrorKey: exception.reason ?: exception.description};
            NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZExceptionError userInfo:userInfo];
            [promise _transitionToState:PZPromiseStateBroken valueOrReason:error isResolved:YES];
        }
    }
    else
    {
        // If there was no on-kept or on-broken block associated with the promise resolution, we simply have the promise adopt the state of the binding promise.
        if (bindingPromiseState == PZPromiseStateKept)
        {
            [promise _transitionToState:PZPromiseStateKept valueOrReason:bindingPromise.keptValue isResolved:YES];
        }
        else
        {
            [promise _transitionToState:PZPromiseStateBroken valueOrReason:bindingPromise.brokenReason isResolved:YES];
        }
        
        _onKept = nil;
        _onBroken = nil;
    }
}

- (void)_resolvePromiseWithBlockResult:(id)blockResult
{
    PZPromise *promise = self.promise;
    if (self.isCancelled || !promise)
    {
        return;
    }
    
    if (self.resolutionCount > PZMaximumResolutionRecursionDepth)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Infinite promise resolution recursion error.",
                                   NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Resolving the promise (<%@:%p>) has exceeded the maximum allowed recursion depth.", [promise class], promise]};
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZRecursionError userInfo:userInfo];
        [promise _transitionToState:PZPromiseStateBroken valueOrReason:error isResolved:YES];
    }
    else if (blockResult == promise)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Infinite promise resolution recursion error.",
                                   NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"The promise (<%@:%p>) cannot be resolved with itself.", [promise class], promise]};
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZRecursionError userInfo:userInfo];
        [promise _transitionToState:PZPromiseStateBroken valueOrReason:error isResolved:YES];
    }
    else if ([blockResult conformsToProtocol:@protocol(PZThenable)])
    {
        // We only allow a single execution of our on-kept or on-broken blocks.
        __block BOOL handlerExecuted = NO;
        
        // We keep this operation around until the promise has finally resolved
        __block _PZResolutionOperation *retainedOperation = self;
        
        // The returned thenable is retained until the promise has resolved.
        self.retainedThenable = [blockResult thenOnKept:^id(id value) {
            retainedOperation.retainedThenable = nil;
            
            if (!handlerExecuted)
            {
                retainedOperation.resolutionCount += 1;
                [retainedOperation _resolvePromiseWithBlockResult:value];
                handlerExecuted = YES;
            }
            
            retainedOperation = nil;
            return nil;
            
        } onBroken:^id(NSError *error) {
            retainedOperation.retainedThenable = nil;
            
            if (!handlerExecuted)
            {
                [promise _transitionToState:PZPromiseStateBroken valueOrReason:error isResolved:YES];
                handlerExecuted = YES;
            }
            
            retainedOperation = nil;
            return nil;
        }];
    }
    else
    {
        // If the value is not a PZThenable or invalid it is used to keep the promise.
        [promise _transitionToState:PZPromiseStateKept valueOrReason:blockResult isResolved:YES];
    }
}

@end

