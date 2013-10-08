//
//  PENetworkOperation.m
//  PromiseExample
//
//  Created by Zachary Radke on 10/1/13.
//  Copyright (c) 2013 Zach Radke. All rights reserved.
//

#import "PENetworkOperation.h"

typedef NS_ENUM(NSInteger, PENetworkOperationState) {
    PENetworkOperationReady = 0,
    PENetworkOperationExecuting,
    PENetworkOperationFinished
};

@interface PENetworkOperation ()

@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSURLConnection *connection;
@property (strong, nonatomic) NSMutableData *buffer;
@property (strong, nonatomic, readwrite) NSError *error;
@property (strong, nonatomic, readwrite) NSData *data;

@property (assign, nonatomic) PENetworkOperationState state;

@end

@implementation PENetworkOperation

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [super init])) {
        _url = url;
        _state = PENetworkOperationReady;
    }
    
    return self;
}

- (void)start {
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    self.state = PENetworkOperationExecuting;
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    }];
}

- (void)cancel {
    [super cancel];
    [self.connection cancel];
    self.state = PENetworkOperationFinished;
}


#pragma mark - State management

+ (NSString *)keyPathForState:(PENetworkOperationState)state {
    switch (state) {
        case PENetworkOperationReady:
            return @"isReady";
        case PENetworkOperationExecuting:
            return @"isExecuting";
        case PENetworkOperationFinished:
            return @"isFinished";
        default:
            return @"state";
    }
}

- (void)setState:(PENetworkOperationState)state {
    NSString *oldKey = [[self class] keyPathForState:_state];
    NSString *newKey = [[self class] keyPathForState:state];
    
    if ([oldKey isEqualToString:newKey]) { return; }
    
    [self willChangeValueForKey:oldKey];
    [self willChangeValueForKey:newKey];
    _state = state;
    [self didChangeValueForKey:newKey];
    [self didChangeValueForKey:oldKey];
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isReady {
    return self.state == PENetworkOperationReady && [super isReady];
}

- (BOOL)isExecuting {
    return self.state == PENetworkOperationExecuting;
}

- (BOOL)isFinished {
    return self.state == PENetworkOperationFinished;
}


#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.buffer = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.buffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.data = [NSData dataWithData:self.buffer];
    self.buffer = nil;
    self.state = PENetworkOperationFinished;
    
    // Keep the inherited promise
    [self.promise keepWithResult:self.data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.error = error;
    self.state = PENetworkOperationFinished;
    
    // Break the inherited promise
    [self.promise breakWithReason:error];
}

@end
