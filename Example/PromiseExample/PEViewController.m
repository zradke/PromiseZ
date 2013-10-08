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
{
    BOOL _isObservingProcessing;
}

@property (assign, nonatomic, getter = isProcessing) BOOL processing;
@property (strong, nonatomic) NSOperationQueue *operationQueue;
@end

@implementation PEViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.transitionImageView.hidden = YES;
    
    [self addObserver:self forKeyPath:@"processing" options:0 context:NULL];
    _isObservingProcessing = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.operationQueue cancelAllOperations];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)dealloc {
    if (_isObservingProcessing) {
        [self removeObserver:self forKeyPath:@"processing"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"processing"]) {
        UIButton *downloadButton = self.downloadButton;
        
        if (self.isProcessing) {
            [downloadButton setTitle:@"Cancel" forState:UIControlStateNormal];
            
        } else {
            [downloadButton setTitle:@"Download" forState:UIControlStateNormal];
            [self.operationQueue cancelAllOperations];
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - Actions

- (IBAction)downloadAction:(UIButton *)sender {
    if (self.isProcessing) {
        self.processing = NO;
        return;
    }
    
    self.processing = YES;
    
    NSString *urlString = @"http://lorempixel.com/1024/1024";
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Here is the promise chain in action:
    // 1. An image is downloaded from the lorempixel API
    // 2. If it succeeds, the image is darkened
    // 3. If that succeeds, the image is blurred
    // If any of the tasks fail, the error trickles into the single error handler
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
        
        // Promises resolve on a background queue, so you must be sure
        // to make UI changes on the main queue, even ones indirectly
        // caused by KVO
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.processing = NO;
        }];
        
        return nil;
        
    } orOnBroken:^id(NSError *error) {
        
        NSLog(@"Error: %@", error);
        
        // Promises resolve on a background queue, so you must be sure
        // to make UI changes on the main queue, even ones indirectly
        // caused by KVO
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.processing = NO;
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
    // Promises resolve on a background queue, so you must be sure
    // to make UI changes on the main queue
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
