//
//  PZPromise.m
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "PZPromise.h"

NSInteger const PZMaximumResolutionRecursionDepth = 10;

NSString *const PZErrorDomain = @"com.zachradke.promiseZ.errorDomain";

@interface _PZResolutionOperation : NSOperation

- (instancetype)initWithPromise:(PZPromise *)promise onKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken NS_DESIGNATED_INITIALIZER;

@property (weak, nonatomic) PZPromise *promise;
@property (copy, nonatomic, readonly) PZOnKeptBlock onKept;
@property (copy, nonatomic, readonly) PZOnBrokenBlock onBroken;

@property (strong, nonatomic) id<PZThenable> retainedThenable;

@property (assign, atomic) NSUInteger resolutionCount;

@end


@interface PZPromise ()

@property (strong, nonatomic) dispatch_queue_t isolationQueue;
@property (strong, nonatomic) NSOperationQueue *resolutionQueue;

@property (strong, nonatomic, readonly) PZPromise *parentPromise;
@property (strong, atomic) PZPromise *bindingPromise;

@end

@implementation PZPromise

- (instancetype)init
{
    if ((self = [super init]))
    {
        _state = PZPromiseStatePending;
        
        _isolationQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL);
        
        _resolutionQueue = [NSOperationQueue new];
        _resolutionQueue.maxConcurrentOperationCount = 1;
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

- (instancetype)initWithParent:(PZPromise *)parentPromise
{
    if (!(self = [self init]))
    {
        return nil;
    }
    
    _parentPromise = parentPromise;
    
    return self;
}

- (void)dealloc
{
    [_resolutionQueue cancelAllOperations];
}

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
                [mutableDescription appendFormat:@", boundTo:<%@:%p>", [self.bindingPromise class], self.bindingPromise];
            }
            
            if (self.parentPromise)
            {
                [mutableDescription appendFormat:@"\n%@", [self.parentPromise descriptionWithLocale:locale indent:level+1]];
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

- (void)keepWithValue:(id)value
{
    [self _async:YES do:^(PZPromise *strongSelf) {
        if (strongSelf.state != PZPromiseStatePending)
        {
            return;
        }
        
        PZPromise *bindingPromise = strongSelf.bindingPromise;
        if (bindingPromise)
        {
            if (bindingPromise.state != PZPromiseStateKept)
            {
                return;
            }
            else if ((bindingPromise.keptValue || value) && (!value || ![bindingPromise.keptValue isEqual:value]))
            {
                return;
            }
        }
        
        [strongSelf willChangeValueForKey:NSStringFromSelector(@selector(state))];
        [strongSelf willChangeValueForKey:NSStringFromSelector(@selector(keptValue))];
        
        strongSelf->_state = PZPromiseStateKept;
        strongSelf->_keptValue = value;
        strongSelf->_parentPromise = nil;
        strongSelf->_bindingPromise = nil;
        
        [strongSelf didChangeValueForKey:NSStringFromSelector(@selector(keptValue))];
        [strongSelf didChangeValueForKey:NSStringFromSelector(@selector(state))];
        
        strongSelf.resolutionQueue.suspended = NO;
    }];
}

- (void)breakWithReason:(NSError *)reason
{
    [self _async:YES do:^(PZPromise *strongSelf) {
        if (strongSelf.state != PZPromiseStatePending)
        {
            return;
        }
        
        PZPromise *bindingPromise = strongSelf.bindingPromise;
        if (bindingPromise)
        {
            if (bindingPromise.state != PZPromiseStateBroken)
            {
                return;
            }
            else if ((bindingPromise.brokenReason || reason) && (!reason || ![bindingPromise.brokenReason isEqual:reason]))
            {
                return;
            }
        }
        
        [strongSelf willChangeValueForKey:NSStringFromSelector(@selector(state))];
        [strongSelf willChangeValueForKey:NSStringFromSelector(@selector(brokenReason))];
        
        strongSelf->_state = PZPromiseStateBroken;
        strongSelf->_brokenReason = reason;
        strongSelf->_parentPromise = nil;
        strongSelf->_bindingPromise = nil;
        
        [strongSelf didChangeValueForKey:NSStringFromSelector(@selector(brokenReason))];
        [strongSelf didChangeValueForKey:NSStringFromSelector(@selector(state))];
        
        strongSelf.resolutionQueue.suspended = NO;
    }];
}

#pragma mark - PZThenable

- (instancetype)thenOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken
{
    __block PZPromise *returnPromise;
    
    [self _async:NO do:^(PZPromise *strongSelf) {
        if (strongSelf.state == PZPromiseStateKept && !onKept)
        {
            returnPromise = [[[strongSelf class] alloc] initWithKeptValue:strongSelf.keptValue];
            return;
        }
        else if (strongSelf.state == PZPromiseStateBroken && !onBroken)
        {
            returnPromise = [[[strongSelf class] alloc] initWithBrokenReason:strongSelf.brokenReason];
            return;
        }
        
        returnPromise = [[[strongSelf class] alloc] initWithParent:strongSelf];
        
        _PZResolutionOperation *operation = [[_PZResolutionOperation alloc] initWithPromise:returnPromise onKept:onKept onBroken:onBroken];
        [strongSelf.resolutionQueue addOperation:operation];
    }];
    
    return returnPromise;
}


#pragma mark - Private

- (void)_async:(BOOL)isAsync do:(void (^)(PZPromise *strongSelf))block
{
    NSParameterAssert(block);
    
    __weak typeof(self) weakSelf = self;
    dispatch_block_t wrappedBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (strongSelf)
        {
            block(strongSelf);
        }
    };
    
    if (isAsync)
    {
        dispatch_async(self.isolationQueue, wrappedBlock);
    }
    else
    {
        dispatch_sync(self.isolationQueue, wrappedBlock);
    }
}

@end


@implementation _PZResolutionOperation

- (instancetype)initWithPromise:(PZPromise *)promise onKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken
{
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
        return;
    }
    
    PZPromise *parentPromise = promise.parentPromise;
    PZPromiseState parentState = parentPromise.state;
    
    if (parentState == PZPromiseStatePending)
    {
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZInternalError userInfo:@{NSLocalizedDescriptionKey: @"The promise started executing its enqueued callback handlers before being kept or broken."}];
        
        [promise breakWithReason:error];
        [parentPromise breakWithReason:error];
    }
    else if ((parentState == PZPromiseStateKept && self.onKept) || (parentState == PZPromiseStateBroken && self.onBroken))
    {
        @try
        {
            id blockResult = (parentState == PZPromiseStateKept) ? self.onKept(parentPromise.keptValue) : self.onBroken(parentPromise.brokenReason);
            [self _resolvePromiseWithBlockResult:blockResult];
        }
        @catch (NSException *exception)
        {
            NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZExceptionError userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
            [promise breakWithReason:error];
        }
    }
    else
    {
        if (parentState == PZPromiseStateKept)
        {
            [promise keepWithValue:parentPromise.keptValue];
        }
        else
        {
            [promise breakWithReason:parentPromise.brokenReason];
        }
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
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZRecursionError userInfo:@{NSLocalizedDescriptionKey: @"The promise's resolution has exceeded the maximum allowed recursion depth"}];
        [promise breakWithReason:error];
    }
    else if (blockResult == promise)
    {
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZRecursionError userInfo:@{NSLocalizedDescriptionKey: @"The promise cannot be resolved with itself"}];
        [promise breakWithReason:error];
    }
    else if ([blockResult conformsToProtocol:@protocol(PZThenable)])
    {
        if ([blockResult isKindOfClass:[PZPromise class]])
        {
            // This prevents the promise from being resolved before the blockResult is.
            promise.bindingPromise = blockResult;
        }
        
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
                [promise breakWithReason:error];
                handlerExecuted = YES;
            }
            
            retainedOperation = nil;
            return nil;
        }];
    }
    else
    {
        [promise keepWithValue:blockResult];
    }
}

@end

