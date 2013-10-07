//
//  PEBaseOperation.m
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import "PEBaseOperation.h"

@interface PEBaseOperation ()
@property (strong, nonatomic, readwrite) PromiseZ *promise;
@end

@implementation PEBaseOperation

- (instancetype)init {
    if ((self = [super init])) {
        _promise = [PromiseZ new];
    }
    
    return self;
}

- (void)cancel {
    [super cancel];
    NSError *error = [NSError errorWithDomain:@"com.zachradke.promiseExample.errorDomain" code:-998 userInfo:@{NSLocalizedDescriptionKey: @"The operation was cancelled"}];
    [self.promise breakWithReason:error];
}

@end
