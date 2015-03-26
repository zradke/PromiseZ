//
//  PZDarkenOperation.m
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "PZDarkenOperation.h"
#import <CoreImage/CoreImage.h>

@interface PZDarkenOperation ()
@end

@implementation PZDarkenOperation

- (instancetype)initWithImage:(UIImage *)image darkenAmount:(CGFloat)darkenAmount
{
    if ((self = [super init]))
    {
        _inputImage = image;
        _darkenAmount = darkenAmount;
    }
    
    return self;
}

- (void)main
{
    if ([self isCancelled])
    {
        return;
    }
    
    CIContext *context = [CIContext contextWithOptions:nil];
    
    CIImage *inputImage = [CIImage imageWithCGImage:[self.inputImage CGImage]];
    
    CIFilter *darkness = [CIFilter filterWithName:@"CIConstantColorGenerator"];
    CIColor *black = [CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:self.darkenAmount];
    [darkness setValue:black forKey:@"inputColor"];
    CIImage *blackImage = [darkness valueForKey:@"outputImage"];
    
    CIFilter *compositeFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [compositeFilter setValue:blackImage forKey:@"inputImage"];
    [compositeFilter setValue:inputImage forKey:@"inputBackgroundImage"];
    
    CIImage *outputImage = [compositeFilter outputImage];
    CGImageRef cgImage = [context createCGImage:outputImage fromRect:inputImage.extent];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    // Keep the inherited promise
    [self.promise keepWithValue:image];
}

@end
