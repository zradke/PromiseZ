//
//  PZDarkenOperation.h
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PZPromiseOperation.h"

@interface PZDarkenOperation : PZPromiseOperation

- (instancetype)initWithImage:(UIImage *)image darkenAmount:(CGFloat)darkenAmount;

@property (strong, nonatomic, readonly) UIImage *inputImage;
@property (assign, nonatomic, readonly) CGFloat darkenAmount;

@end
