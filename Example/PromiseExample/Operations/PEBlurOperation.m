//
//  PEBlurOperation.m
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import "PEBlurOperation.h"
#import <CoreImage/CoreImage.h>

@interface PEBlurOperation ()
@property (assign, nonatomic) CGFloat blurAmount;
@property (strong, nonatomic) UIImage *inputImage;
@property (strong, nonatomic, readwrite) UIImage *outputImage;
@end

@implementation PEBlurOperation

- (instancetype)initWithImage:(UIImage *)image blurAmount:(CGFloat)blurAmount {
    if ((self = [super init])) {
        _inputImage = image;
        _blurAmount = blurAmount;
    }
    
    return self;
}

- (void)main {
    if ([self isCancelled]) { return; }
    
    CIContext *context = [CIContext contextWithOptions:nil];
    
    CIImage *inputImage = [CIImage imageWithCGImage:[self.inputImage CGImage]];
    
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setDefaults];
    [blurFilter setValue:@(self.blurAmount) forKey:@"inputRadius"];
    [blurFilter setValue:inputImage forKey:kCIInputImageKey];
    
    CIImage *outputImage = [blurFilter outputImage];
    CGImageRef cgImage = [context createCGImage:outputImage fromRect:inputImage.extent];
    self.outputImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    // Keep the inherited promise
    [self.promise keepWithResult:self.outputImage];
}

@end
