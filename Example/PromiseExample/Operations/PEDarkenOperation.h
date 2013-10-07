//
//  PEDarkenOperation.h
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PEBaseOperation.h"

@interface PEDarkenOperation : PEBaseOperation

- (instancetype)initWithImage:(UIImage *)image darkenAmount:(CGFloat)darkenAmount;

@property (strong, nonatomic, readonly) UIImage *outputImage;

@end
