//
//  PENetworkOperation.h
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PEBaseOperation.h"

@interface PENetworkOperation : PEBaseOperation <NSURLConnectionDataDelegate>

- (instancetype)initWithURL:(NSURL *)url;

@property (strong, nonatomic, readonly) NSError *error;
@property (strong, nonatomic, readonly) NSData *data;

@end
