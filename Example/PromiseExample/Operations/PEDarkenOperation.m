//
//  PEDarkenOperation.m
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import "PEDarkenOperation.h"
#import <CoreImage/CoreImage.h>

@interface PEDarkenOperation ()
@property (assign, nonatomic) CGFloat darkenAmount;
@property (strong, nonatomic) UIImage *inputImage;
@property (strong, nonatomic, readwrite) UIImage *outputImage;
@end

@implementation PEDarkenOperation

- (instancetype)initWithImage:(UIImage *)image darkenAmount:(CGFloat)darkenAmount {
    if ((self = [super init])) {
        _inputImage = image;
        _darkenAmount = darkenAmount;
    }
    
    return self;
}

- (void)main {
    if ([self isCancelled]) { return; }
    
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
    self.outputImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    [self.promise keepWithResult:self.outputImage];
}

@end
