//
//  PromiseZ.m
//  PromiseZ
//
//  Created by Zachary Radke on 7/31/13.
//  Copyright (c) 2013 Zachary Radke. All rights reserved.
//

#import "PromiseZ.h"

NSInteger const PZMaximumRecursiveResolutionDepth = 30;

NSString *const PZErrorDomain = @"com.zachradke.promiseZ.errorDomain";
NSInteger const PZTypeError = 1900;
NSInteger const PZExceptionError = 1910;
NSInteger const PZRecursionError = 1920;
NSInteger const PZInternalError = 1930;

static inline NSString *PZStringFromPromiseState(PZPromiseState state) {
    switch (state) {
        case PZPromiseStatePending:
            return @"isPending";
        case PZPromiseStateKept:
            return @"isKept";
        case PZPromiseStateBroken:
            return @"isBroken";
        default:
            return @"Unknown";
    }
}

@interface PromiseZ ()
@property (strong, nonatomic) NSOperationQueue *handlerQueue;
@property (assign, nonatomic) NSInteger recursiveResolutionCount;
@property (strong, nonatomic) NSRecursiveLock *lock;

@property (strong, nonatomic, readwrite) id result;
@property (assign, nonatomic, readwrite) PZPromiseState state;
@property (weak, nonatomic, readwrite) PromiseZ *bindingPromise;
@end

@implementation PromiseZ

- (instancetype)init {
    if ((self = [super init])) {
        _handlerQueue = [NSOperationQueue new];
        _handlerQueue.name = [NSString stringWithFormat:@"com.zachradke.promiseZ.%p.handlerQueue", self];
        _handlerQueue.maxConcurrentOperationCount = 1;
        [_handlerQueue setSuspended:YES];
        
        _lock = [NSRecursiveLock new];
        _lock.name = [NSString stringWithFormat:@"com.zachradke.promiseZ.%p.lock", self];
    }
    
    return self;
}

- (void)dealloc {
    [_handlerQueue cancelAllOperations];
}

- (void)cancelAllCallbacks {
    [self.handlerQueue cancelAllOperations];
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: %p, state: %@, result: %@", NSStringFromClass([self class]), self, PZStringFromPromiseState([self state]), [self result]];
    if ([self isBound]) {
        [description appendFormat:@", binding promise: %p>", [self bindingPromise]];
    } else {
        [description appendString:@">"];
    }
    return [description copy];
}


#pragma mark - State checks

- (BOOL)isPending {
    return ([self state] == PZPromiseStatePending);
}

- (BOOL)isKept {
    return ([self state] == PZPromiseStateKept);
}

- (BOOL)isBroken {
    return ([self state] == PZPromiseStateBroken);
}

- (BOOL)isBound {
    return ([self bindingPromise] != nil);
}


#pragma mark - Keeping, breaking, and binding promises

- (void)satisfyWithResult:(id)result state:(PZPromiseState)state {
    if (![self isPending] || ([self isBound] && [[self bindingPromise] result] != result)) {
        return;
    }
    
    [self.lock lock];
    
    self.result = result;
    self.state = state;
    self.recursiveResolutionCount = 0;
    [[self handlerQueue] setSuspended:NO];
    
    [self.lock unlock];
}

- (void)keepWithResult:(id)result {
    [self satisfyWithResult:result state:PZPromiseStateKept];
}

- (void)breakWithReason:(NSError *)reason {
    [self satisfyWithResult:reason state:PZPromiseStateBroken];
}

- (void)bindToPromise:(PromiseZ *)promise {
    if ([self isBound]) { return; }
    
    [self.lock lock];
    
    self.bindingPromise = promise;
    
    __weak typeof(self) weakSelf = self;
    [promise enqueueOnKept:^id(id value) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf satisfyWithResult:value state:PZPromiseStateKept];
        return nil;
        
    } onBroken:^id(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf satisfyWithResult:error state:PZPromiseStateBroken];
        return nil;
    } returnPromise:NO];
    
    [self.lock unlock];
}


#pragma mark - Resolving promises

- (void)resolveWithHandlerResult:(id)result {
    if (self.recursiveResolutionCount > PZMaximumRecursiveResolutionDepth) {
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZRecursionError userInfo:@{NSLocalizedDescriptionKey: @"The promise's resolution has exceeded the maximum allowed recursion depth"}];
        [self breakWithReason:error];
        
    } else if ([result isEqual:self]) {
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZTypeError userInfo:@{NSLocalizedDescriptionKey: @"The promise cannot be resolved with itself"}];
        [self breakWithReason:error];
        
    } else if ([result isKindOfClass:[self class]]) {
        [self bindToPromise:result];
        
    } else if ([result conformsToProtocol:@protocol(PZThenable)]) {
        __weak typeof(self) weakSelf = self;
        __block BOOL handlerExecuted = NO;
        
        [result thenOnKept:^id(id value) {
            if (handlerExecuted) { return nil; }
            
            typeof(self) strongSelf = weakSelf;
            strongSelf.recursiveResolutionCount += 1;
            [strongSelf resolveWithHandlerResult:value];
            handlerExecuted = YES;
            return nil;
            
        } orOnBroken:^id(NSError *error) {
            if (handlerExecuted) { return nil; }
            
            typeof(self) strongSelf = weakSelf;
            [strongSelf breakWithReason:error];
            handlerExecuted = YES;
            return nil;
        }];
    } else {
        [self keepWithResult:result];
    }
}

- (void)resolveHandlerBlock:(id (^)(id))handlerBlock withDependentPromise:(PromiseZ *)dependentPromise {
    @try {
        if (handlerBlock) {
            id handlerResult = handlerBlock([self result]);
            [dependentPromise resolveWithHandlerResult:handlerResult];
            
        } else {
            [dependentPromise satisfyWithResult:[self result] state:[self state]];
        }
    }
    @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZExceptionError userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        [dependentPromise breakWithReason:error];
    }
}


#pragma mark - Adding callback handlers

- (instancetype)enqueueOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken returnPromise:(BOOL)shouldReturnPromise {
    typeof(self) returnPromise = shouldReturnPromise ? [[self class] new] : nil;
    __weak typeof(returnPromise) weakReturnedPromise = returnPromise;
    
    NSBlockOperation *operation = [NSBlockOperation new];
    __weak NSBlockOperation *weakOperation = operation;
    [operation addExecutionBlock:^{
        if ([weakOperation isCancelled]) { return; }
        
        __strong typeof(weakReturnedPromise) strongReturnedPromise = weakReturnedPromise;
        
        if ([self isKept]) {
            [self resolveHandlerBlock:onKept withDependentPromise:strongReturnedPromise];
            
        } else if ([self isBroken]) {
            [self resolveHandlerBlock:onBroken withDependentPromise:strongReturnedPromise];
            
        } else {
            NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZInternalError userInfo:@{NSLocalizedDescriptionKey: @"The promise started executing its enqueued callback handlers before being kept or broken."}];
            [self breakWithReason:error];
            [strongReturnedPromise breakWithReason:error];
        }
    }];
    
    [self.handlerQueue addOperation:operation];
    
    return returnPromise;
}

- (instancetype)thenOnKept:(PZOnKeptBlock)onKept orOnBroken:(PZOnBrokenBlock)onBroken {
    return [self enqueueOnKept:onKept onBroken:onBroken returnPromise:YES];
}

@end
