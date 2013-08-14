//
//  PromiseZ_Private.h
//  PromiseZ
//
//  Created by Zachary Radke on 8/7/13.
//  Copyright (c) 2013 Zachary Radke. All rights reserved.
//

#import "PromiseZ.h"

@interface PromiseZ ()

@property (strong, nonatomic) NSOperationQueue *handlerQueue;
@property (assign, nonatomic) NSInteger recursiveResolutionCount;

- (void)bindToPromise:(PromiseZ *)promise;
- (void)resolveWithHandlerResult:(id)result;
- (void)resolveHandlerBlock:(id (^)(id))handlerBlock withDependentPromise:(PromiseZ *)dependentPromise;
- (instancetype)enqueueOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken returnPromise:(BOOL)shouldReturnPromise;

@end
