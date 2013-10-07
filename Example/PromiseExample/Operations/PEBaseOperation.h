//
//  PEBaseOperation.h
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PromiseZ.h"

@interface PEBaseOperation : NSOperation

@property (strong, nonatomic, readonly) PromiseZ *promise;

@end
