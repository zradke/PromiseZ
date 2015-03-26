//
//  PZBlurOperation.m
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "PZBlurOperation.h"
#import <CoreImage/CoreImage.h>

@interface PZBlurOperation ()

@end

@implementation PZBlurOperation

- (instancetype)initWithImage:(UIImage *)image blurAmount:(CGFloat)blurAmount
{
    if ((self = [super init]))
    {
        _inputImage = image;
        _blurAmount = blurAmount;
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
    
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setDefaults];
    [blurFilter setValue:@(self.blurAmount) forKey:@"inputRadius"];
    [blurFilter setValue:inputImage forKey:kCIInputImageKey];
    
    CIImage *outputImage = [blurFilter outputImage];
    CGImageRef cgImage = [context createCGImage:outputImage fromRect:inputImage.extent];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    // Keep the inherited promise
    [self.promise keepWithValue:image];
}

@end
