//
//  PZPromiseOperation.h
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PromiseZ/PZPromise.h>

@interface PZPromiseOperation : NSOperation

@property (strong, nonatomic) PZPromise *promise;

@end
