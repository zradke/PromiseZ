//
//  PZViewController.m
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "PZViewController.h"

#import "PZDarkenOperation.h"
#import "PZBlurOperation.h"

#import <PromiseZ/PZPromise.h>
#import <KVOController/FBKVOController.h>
#import <AFNetworking/AFNetworking.h>

@interface PZViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *mainImageView;
@property (weak, nonatomic) IBOutlet UIImageView *transitionImageView;
@property (weak, nonatomic) IBOutlet UIButton *button;

@property (assign, nonatomic) BOOL isProcessing;
@property (strong, nonatomic) NSOperationQueue *operationQueue;

@property (strong, nonatomic) PZPromise *promise;

@end

@implementation PZViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.operationQueue = [NSOperationQueue new];
        
    [self.KVOControllerNonRetaining observe:self keyPath:NSStringFromSelector(@selector(isProcessing)) options:0 action:@selector(didChangeProcessing)];
    [self didChangeProcessing];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)didChangeProcessing
{
    dispatch_block_t block = ^{
        UIButton *button = self.button;
        
        if (self.isProcessing) {
            [button setTitle:@"Cancel" forState:UIControlStateNormal];
            
        } else {
            [button setTitle:@"Download" forState:UIControlStateNormal];
            [self.operationQueue cancelAllOperations];
        }
    };
    
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)didChangePromiseState
{
    self.isProcessing = NO;
    
    if (self.promise.state == PZPromiseStateKept)
    {
        NSLog(@"Did blur image...");
        [self animateImage:self.promise.keptValue];
    }
    else
    {
        NSLog(@"Error: %@", self.promise.brokenReason);
    }
}

- (IBAction)didTapButton:(id)sender
{
    if (self.isProcessing)
    {
        self.isProcessing = NO;
        
        [self.KVOController unobserve:self.promise];
        self.promise = nil;
        
        return;
    }
    
    self.isProcessing = YES;
    
    NSURL *url = [NSURL URLWithString:@"http://lorempixel.com/1024/1024"];
    self.promise = [[[self downloadPromiseForImageURL:url] thenOnKept:^id(id value) {
        NSLog(@"Did download image...");
        [self animateImage:value];
        return [self darkenPromiseForImage:value];
    } onBroken:nil] thenOnKept:^id(id value) {
        NSLog(@"Did darken image...");
        [self animateImage:value];
        return [self blurPromiseForImage:value];
    } onBroken:nil];
    
    [self.KVOController observe:self.promise keyPath:NSStringFromSelector(@selector(state)) options:0 action:@selector(didChangePromiseState)];
}

- (void)animateImage:(UIImage *)image
{
    dispatch_block_t block = ^{
        UIImageView *bottomImageView = self.mainImageView;
        UIImageView *transitionView = self.transitionImageView;
        
        transitionView.image = image;
        transitionView.layer.opacity = 0.0;
        
        [UIView animateWithDuration:0.25 animations:^{
            transitionView.layer.opacity = 1.0;
        } completion:^(BOOL finished) {
            bottomImageView.image = image;
        }];
    };
    
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (PZPromise *)downloadPromiseForImageURL:(NSURL *)imageURL
{
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:[NSURLRequest requestWithURL:imageURL]];
    operation.responseSerializer = [AFImageResponseSerializer serializer];
    
    __block PZPromise *promise = [PZPromise new];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [promise keepWithValue:responseObject];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [promise breakWithReason:error];
    }];
    
    [self.operationQueue addOperation:operation];
    
    return promise;
}

- (PZPromise *)darkenPromiseForImage:(UIImage *)image
{
    PZDarkenOperation *operation = [[PZDarkenOperation alloc] initWithImage:image darkenAmount:0.9];
    [self.operationQueue addOperation:operation];
    return operation.promise;
}

- (PZPromise *)blurPromiseForImage:(UIImage *)image
{
    PZBlurOperation *operation = [[PZBlurOperation alloc] initWithImage:image blurAmount:8.0];
    [self.operationQueue addOperation:operation];
    return operation.promise;
}


@end
