//
//  PEViewController.m
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import "PEViewController.h"
#import "PEBlurOperation.h"
#import "PEDarkenOperation.h"
#import "PENetworkOperation.h"
#import "PromiseZ.h"

@interface PEViewController ()
@property (assign, nonatomic, getter = isProcessing) BOOL processing;
@property (strong, nonatomic) NSOperationQueue *operationQueue;
@end

@implementation PEViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.transitionImageView.hidden = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.operationQueue cancelAllOperations];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - Actions

- (IBAction)downloadAction:(UIButton *)sender {
    if (self.isProcessing) {
        self.processing = NO;
        [sender setTitle:@"Download" forState:UIControlStateNormal];
        [self.operationQueue cancelAllOperations];
        return;
    }
    
    self.processing = YES;
    [sender setTitle:@"Cancel" forState:UIControlStateNormal];
    
    NSString *urlString = @"http://lorempixel.com/1024/1024";
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[[[self downloadOperationWithImageURL:url] thenOnKept:^id(id value) {
        
        NSLog(@"Downloaded the image!");
        
        UIImage *image = [UIImage imageWithData:value];
        [self animateImageOnMainQueue:image];
        
        return [self darkenOperationWithImage:image];
        
    } orOnBroken:nil] thenOnKept:^id(id value) {
        
        NSLog(@"Darkened the image!");
        
        [self animateImageOnMainQueue:value];
        
        return [self blurOperationWithImage:value];
        
    } orOnBroken:nil] thenOnKept:^id(id value) {
        
        NSLog(@"Blurred the image!");
        
        [self animateImageOnMainQueue:value];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.processing = NO;
            [sender setTitle:@"Download" forState:UIControlStateNormal];
        }];
        
        return nil;
        
    } orOnBroken:^id(NSError *error) {
        NSLog(@"Error: %@", error);
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.processing = NO;
            [sender setTitle:@"Download" forState:UIControlStateNormal];
        }];
        
        return nil;
    }];
    
}


#pragma mark - Operations

- (NSOperationQueue *)operationQueue {
    if (!_operationQueue) {
        _operationQueue = [NSOperationQueue new];
    }
    
    return _operationQueue;
}

- (void)animateImageOnMainQueue:(UIImage *)image
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        UIImageView *transitionView = self.transitionImageView;
        
        transitionView.image = image;
        transitionView.layer.opacity = 0.0;
        transitionView.hidden = NO;
        
        [UIView animateWithDuration:0.25 animations:^{
            transitionView.layer.opacity = 1.0;
        } completion:^(BOOL finished) {
            self.mainImageView.image = image;
            transitionView.layer.hidden = YES;
        }];
    }];
}

- (PromiseZ *)downloadOperationWithImageURL:(NSURL *)imageURL {
    PENetworkOperation *operation = [[PENetworkOperation alloc] initWithURL:imageURL];
    [self.operationQueue addOperation:operation];
    return operation.promise;
}

- (PromiseZ *)darkenOperationWithImage:(UIImage *)image {
    PEDarkenOperation *operation = [[PEDarkenOperation alloc] initWithImage:image darkenAmount:0.9];
    [self.operationQueue addOperation:operation];
    return operation.promise;
}

- (PromiseZ *)blurOperationWithImage:(UIImage *)image {
    PEBlurOperation *operation = [[PEBlurOperation alloc] initWithImage:image blurAmount:8.0];
    [self.operationQueue addOperation:operation];
    return operation.promise;
}

@end
