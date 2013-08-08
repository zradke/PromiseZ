//
//  PromiseZ.m
//  PromiseZ
//
//  Created by Zachary Radke on 7/31/13.
//  Copyright (c) 2013 Zachary Radke. All rights reserved.
//

#import "PromiseZ_Private.h"
#import "PromiseZ.h"

NSInteger const PZMaximumRecursiveResolutionDepth = 30;

NSString *const PZErrorDomain = @"com.zachradke.PromiseZ.ErrorDomain";
NSInteger const PZTypeError = 1900;
NSInteger const PZExceptionError = 1910;
NSInteger const PZRecursionError = 1920;

@implementation PromiseZ

- (instancetype)init {
    if ((self = [super init])) {
        _handlerQueue = [NSOperationQueue new];
        [_handlerQueue setMaxConcurrentOperationCount:1];
        [_handlerQueue setSuspended:YES];
    }
    
    return self;
}

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

- (void)satisfyWithResult:(id)result state:(PZPromiseState)state {
    if (![self isPending] || ([self isBound] && [[self bindingPromise] result] != result)) {
        return;
    }
    _result = result;
    _state = state;
    [self setRecursiveResolutionCount:0];
    [[self handlerQueue] setSuspended:NO];
}

- (void)keepWithResult:(id)result {
    [self satisfyWithResult:result state:PZPromiseStateKept];
}

- (void)breakWithReason:(NSError *)reason {
    [self satisfyWithResult:reason state:PZPromiseStateBroken];
}

- (void)bindToPromise:(PromiseZ *)promise {
    if ([self isBound]) { return; }
    _bindingPromise = promise;
    __weak typeof(self) weakSelf = self;
    [promise enqueueOnKept:^id(id value) {
        typeof(self) strongSelf = weakSelf;
        [strongSelf keepWithResult:value];
        return nil;
    } onBroken:^id(NSError *error) {
        typeof(self) strongSelf = weakSelf;
        [strongSelf breakWithReason:error];
        return nil;
    } returnPromise:NO];
}

- (void)resolveWithHandlerResult:(id)result {
    if (self.recursiveResolutionCount > PZMaximumRecursiveResolutionDepth) {
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZRecursionError userInfo:@{NSLocalizedDescriptionKey: @"Promise resolution has exceeded the maximum allowed recursion depth"}];
        [self breakWithReason:error];
    } else if ([result isEqual:self]) {
        NSError *error = [NSError errorWithDomain:PZErrorDomain code:PZTypeError userInfo:@{NSLocalizedDescriptionKey: @"Cannot resolve a promise with itself"}];
        [self breakWithReason:error];
    } else if ([result isKindOfClass:[self class]]) {
        [self bindToPromise:result];
    } else if ([result conformsToProtocol:@protocol(PZThenable)]) {
        __weak typeof(self) weakSelf = self;
        [result thenOnKept:^id(id value) {
            typeof(self) strongSelf = weakSelf;
            strongSelf.recursiveResolutionCount += 1;
            [strongSelf resolveWithHandlerResult:value];
            return nil;
        } orOnBroken:^id(NSError *error) {
            typeof(self) strongSelf = weakSelf;
            [strongSelf breakWithReason:error];
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

- (instancetype)enqueueOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken returnPromise:(BOOL)shouldReturnPromise {
    typeof(self) returnPromise = shouldReturnPromise ? [[self class] new] : nil;
    
    __weak typeof(self) weakReturnPromise = returnPromise;
    __weak typeof(self) weakSelf = self;
    [self.handlerQueue addOperationWithBlock:^{
        typeof(self) strongReturnPromise = weakReturnPromise;
        typeof(self) strongSelf = weakSelf;
        if ([strongSelf isKept]) {
            [strongSelf resolveHandlerBlock:onKept withDependentPromise:strongReturnPromise];
        } else if ([strongSelf isBroken]) {
            [strongSelf resolveHandlerBlock:onBroken withDependentPromise:strongReturnPromise];
        }
    }];
    
    return returnPromise;
}

- (instancetype)thenOnKept:(PZOnKeptBlock)onKept orOnBroken:(PZOnBrokenBlock)onBroken {
    return [self enqueueOnKept:onKept onBroken:onBroken returnPromise:YES];
}

@end
