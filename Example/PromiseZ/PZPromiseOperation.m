//
//  PZPromiseOperation.h
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "PZPromiseOperation.h"

@implementation PZPromiseOperation

- (instancetype)init
{
    if ((self = [super init]))
    {
        // All subclasses of this will have an internal promise
        _promise = [PZPromise new];
    }
    
    return self;
}

- (void)cancel
{
    [super cancel];
    
    // Cancelling an operation will break its promise
    NSError *error = [NSError errorWithDomain:@"com.zachradke.promiseExample.errorDomain" code:-998 userInfo:@{NSLocalizedDescriptionKey: @"The operation was cancelled"}];
    [self.promise breakWithReason:error];
}

@end
