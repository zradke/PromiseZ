//
//  PromiseZ.h
//  PromiseZ
//
//  Created by Zachary Radke on 7/31/13.
//  Copyright (c) 2013 Zachary Radke. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef id(^PZOnKeptBlock)(id value);
typedef id(^PZOnBrokenBlock)(NSError *error);

typedef NS_ENUM(NSInteger, PZPromiseState) {
    PZPromiseStatePending = 0,
    PZPromiseStateKept,
    PZPromiseStateBroken
};

extern NSInteger const PZMaximumRecursiveResolutionDepth;

extern NSString *const PZErrorDomain;
extern NSInteger const PZTypeError;
extern NSInteger const PZExceptionError;
extern NSInteger const PZRecursionError;


@protocol PZThenable <NSObject>
@required
- (id<PZThenable>)thenOnKept:(PZOnKeptBlock)onKept orOnBroken:(PZOnBrokenBlock)onBroken;
@end

@interface PromiseZ : NSObject <PZThenable>

@property (assign, readonly) PZPromiseState state;
@property (strong, readonly) id result;
@property (weak, readonly) PromiseZ *bindingPromise;

- (BOOL)isPending;
- (BOOL)isKept;
- (BOOL)isBroken;
- (BOOL)isBound;

- (void)keepWithResult:(id)result;
- (void)breakWithReason:(NSError *)reason;
- (void)bindToPromise:(PromiseZ *)promise;

@end
