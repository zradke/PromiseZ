//
//  PZPromise.h
//  PromiseZ
//
//  Created by Zach Radke on 3/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  Block passed to PZThenable conformers and executed when the thenable resolves in success.
 *
 *  @see [PZThenable thenOnKept:onBroken:]
 *
 *  @param value The successfully acquired value by the thenable.
 *
 *  @return An optional return value which influences the promise returned by the thenable.
 *
 */
typedef id(^PZOnKeptBlock)(id value);

/**
 *  BLock passed to PZThenable conformers and executed when the thenable fails to resolve.
 *
 *  @see [PZThenable thenOnKept:onBroken:]
 *
 *  @param reason The reason the thenable failed to acquire a value.
 *
 *  @return An optional return value which influences the promise returned by the thenable.
 */
typedef id(^PZOnBrokenBlock)(NSError *reason);

/**
 *  Possible states for a PZPromise.
 */
typedef NS_ENUM(NSInteger, PZPromiseState)
{
    /**
     *  The promise has yet to resolve in either success or failure.
     */
    PZPromiseStatePending = 0,
    /**
     *  The promise has resolved in success.
     */
    PZPromiseStateKept,
    /**
     *  The promise has failed.
     */
    PZPromiseStateBroken
};

/**
 *  The maximum recursion depth allowed by PZPromise when resolving returned PZThenable conformers. After this depth has been reached, the pending promise will be broken with a PZRecursionError.
 */
FOUNDATION_EXPORT NSInteger const PZMaximumResolutionRecursionDepth;

/**
 *  The error domain for PromiseZ
 */
FOUNDATION_EXPORT NSString *const PZErrorDomain;

enum
{
    /**
     *  Error when an exception is raised while trying to execute on-kept or on-broken blocks.
     */
    PZExceptionError = 1910,
    /**
     *  Error when resolving a promise would lead to an infinite cycle. This can be because an on-kept or on-broken block returns the pending promise itself, or because a thenable's implementation exceeds the PZMaximumResolutionRecursionDepth.
     */
    PZRecursionError = 1920,
    /**
     *  Error when a promise is put in an inconsistent state. For example, if a promise somehow attempts to begin resolving on-kept or on-broken blocks before being resolved itself, it will be broken with this error.
     */
    PZInternalError = 1930
};


/**
 *  Protocol which conformers can adopt to demonstrate that they have a pending value which will be resolved.
 *
 *  A concrete example of this protocol is the PZPromise class, which also conforms to the Promises/A+ spec. Though PZThenable conformers do not necessarily need to conform to the spec in its entirety, they may benefit from 
 */
@protocol PZThenable <NSObject>
@required

/**
 *  Asks the receiver to notify the caller via the on-kept and on-broken blocks when it has succeeded or failed in an arbitrary task. The method should return another PZThenable conforming object whose state will depend on the success or failure of the receiver, as well as any values returned from the blocks.
 *
 *  @see PZPromise
 *
 *  @param onKept   An optional block which is executed when the receiver succeeds in an arbitrary task. This block can return a value which influences the resolution of the returned PZThenable.
 *  @param onBroken An optional block which is executed when the receiver fails at an arbitrary task. This block can return a value which influences the resolution of the returned PZThenable.
 *
 *  @return A PZThenable whose resolution depends on the the on-kept and on-broken blocks. This can then be used to chain the -thenOnKept:onBroken: method together.
 */
- (id<PZThenable>)thenOnKept:(PZOnKeptBlock)onKept onBroken:(PZOnBrokenBlock)onBroken;

@end


/**
 *  A concrete conformer of the PZThenable protocol and the Promises/A+ spec. A PZPromise represents a possible future value which can be asynchronously accessed.
 *
 *  Because PZPromise conforms to the Promises/A+ spec, it has a specific implementation of the [PZThenable thenOnKept:onBroken:] method. First, the method will always return a new promise. Second, if you provide an on-kept or on-broken block, the return value of the block will resolve the new returned promise. If the block returns a PZPromise, the new promise will be locked (i.e. -keepWithValue: and -breakWithReason: will have no affect) until the block's promise resolves. If a PZThenable is returned the effect is similar, but the new promise can be independently resolved before the PZThenable resolves. And any other object is returned, it will -keepWithValue: the new promise using the block value. In the absense of an on-kept or on-broken block, the new promise will simply adopt the state of the receiving promise.
 */
@interface PZPromise : NSObject <PZThenable>

/**
 *  @name Creating promises
 */

/**
 *  Factory for creating a pending promise.
 *
 *  @return A new pending promise.
 */
+ (instancetype)promise;

/**
 *  The designated initializer. Initializes a pending promise awaiting a value.
 *
 *  @return An initialized instance of the receiver.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 *  Convenience initializer which produces an already kept promise.
 *
 *  @param keptValue The value to keep the promise with.
 *
 *  @return An initialized instance of the receiver with a kept value and state.
 */
- (instancetype)initWithKeptValue:(id)keptValue;

/**
 *  Convenience initializer which produces an already broken promise.
 *
 *  @param brokenReason The reason the promise is broken.
 *
 *  @return An initialized instance of the receiver with a broken reason and state.
 */
- (instancetype)initWithBrokenReason:(NSError *)brokenReason;


/**
 *  @name State properties
 */

/**
 *  The state of the receiver. This is KVC compliant.
 */
@property (assign, nonatomic, readonly) PZPromiseState state;

/**
 *  The value the promise was kept with, if it exists. Note that it is possible to keep a promise with `nil`, so to find out if the receiver has been kept, use the state property instead. This is KVC compliant.
 */
@property (strong, nonatomic, readonly) id keptValue;

/**
 *  The reason the promise was broken, if it exists. Note that it is possible to break a promise with `nil`, so to find out if the receiver is broken, use the state property instead. This is KVC compliant.
 */
@property (strong, nonatomic, readonly) NSError *brokenReason;


/**
 *  @name Keeping and breaking promises
 */

/**
 *  Asynchronously keeps the receiver with the given value. Note that this method will have no effect if the promise is already kept, broken, or if it is bound to another promise via the [PZThenable thenOnKept:onBroken:] method.
 *
 *  @param value The value to keep the promise with. This can be nil.
 */
- (void)keepWithValue:(id)value;

/**
 *  Asynchronously breaks the receiver with the given reason. Note that this method will have no effect if the promise is already kept, broken, or if it is bound to another promise via the [PZThenable thenOnKept:onBroken:] method.
 *
 *  @param reason The reason to break the promise. This can be nil.
 */
- (void)breakWithReason:(NSError *)reason;

@end
