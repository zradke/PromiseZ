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

/**
 * The PZThenable protocol declares a reliable interface for objects to work
 * with PromiseZ instances and be chainable. Typically classes can choose to adopt this
 * protocol while transitioning into working with PromiseZ.
 *
 * As defined in the Promises/A+ spec, a "thenable" is any object which implements a
 * "then" method, which takes two blocks: an onKept block and and onBroken block, which
 * may or may not be executed at some point in the future. Thenables are not required
 * to obey the other specifications which promises must implement, but they can return
 * another object which adopts the PZThenable protocol, or nothing if they choose.
 *
 * ## Type definitions:
 *
 * - *PZOnKeptBlock*: id(^)(id value)
 * - *PZOnBrokenBlock*: id(^)(NSError *reason)
 */
@protocol PZThenable <NSObject>
@required

/**
 * Method representing actions which may or may not be executed some time in the future
 * by the implementing class. This method may return another PZThenable object which
 * allows for chaining.
 *
 * @param onKept A PZOnKeptBlock which may be called if the implementing class is
 * successful. This block can optionally return a value, which will be resolved in a
 * PromiseZ object, or by the implementing class.
 * @param onBroken A PZOnBrokenBlock which may be called if the implementing class is
 * unsuccessful. The block can optionally return a value, which will be resolved in a
 * PromiseZ object, or by the implementing class.
 * @return Another PZThenable object, or nil
 */
- (id<PZThenable>)thenOnKept:(PZOnKeptBlock)onKept orOnBroken:(PZOnBrokenBlock)onBroken;
@end

typedef NS_ENUM(NSInteger, PZPromiseState) {
    PZPromiseStatePending = 0,
    PZPromiseStateKept,
    PZPromiseStateBroken
};

extern NSString *const PZPromiseWasKeptNotification;
extern NSString *const PZPromiseWasBrokenNotification;

extern NSInteger const PZMaximumRecursiveResolutionDepth;

extern NSString *const PZErrorDomain;
extern NSInteger const PZTypeError;
extern NSInteger const PZExceptionError;
extern NSInteger const PZRecursionError;
extern NSInteger const PZInternalError;


/**
 * A PromiseZ object represents a future result of an action which may or may not
 * be successful. It follows the Promises/A+ spec and conforms to the PZThenable
 * protocol. A PromiseZ thenOnKept:orOnBroken: method will always return another
 * PromiseZ instance, allowing operations to be chained. Depending on the type
 * of value returned by the onKept and onBroken handlers, this returned promise can
 * be kept, broken, bound, or otherwise resolved.
 *
 * ## State transitions
 *
 * PromiseZ have three states:
 *
 * - PZPromiseStatePending
 * - PZPromiseStateKept
 * - PZPromiseStateBroken
 *
 * A promise can only ever be one state at a time, and it always begins as a
 * pending promise. When the promise is kept or broken, it's state will change, and
 * remains fixed. The result property stores the eventual successful result or
 * failure reason. Once set, it will never change.
 *
 * A method or object can keep or break a promise using the keepWithResult: and
 * breakWithReason: methods respectively. When either method successfully runs, it
 * will start executing enqueued onKept or onBroken handlers. If either is called
 * on an already resolved promise, they will do nothing. Similarly, if the promise
 * has been bound to another promise, it cannot be kept or broken by any other value
 * than the binding promise's result.
 *
 * ## Binding promises
 *
 * Promises can be manually bound to other promises using the bindToPromise:
 * method. They are also automatically bound in the thenOnKept:orOnBroken:
 * method, which returns a new PromiseZ. That returned promise is bound to
 * a PromiseZ returned by the onKept or onBroken blocks.
 *
 * When a promise is bound, it automatically sets itself to be kept or
 * broken when it's bindingPromise is kept or broken. The binding promise is
 * stored in the bindingPromise property, which is weakly held. If the bindingPromise
 * is deallocated for any reason, the bound promise will become unbound, and can be
 * manually kept or broken.
 *
 * ## Resolving handler values
 *
 * When a promise is fulfilled or broken, it will resolve the appropriate handlers
 * enqueued in the order that they were added (via the thenOnKept:orOnBroken: method).
 * While executing these onKept or onBroken handlers, any values returned by those
 * handlers will be used to resolve the PromiseZ returned by the 
 * thenOnKept:orOnBroken: method. For more detail on the resolution mechanism, please
 * check the Promises/A+ spec. In general, however, the returned value is used to
 * resolve the returned promise in some way.
 *
 * When dealing with handlers that return PZThenable conformant objects, the promise
 * resolves itself using recursion. This can lead to an infinite loop, which is 
 * resolved with the PZMaximumRecursiveResolutionDepth constant, after which point the
 * loop is broken and the promise is broken with a PZRecursionError.
 *
 * ## Error handling
 *
 * With the implementation of the thenOnSuccess:orOnFailure: method, everything passed
 * is protected against exceptions. Any exception raised in the invoking of the
 * handler blocks is caught, and triggers a breakWithReason:, passing a
 * PZExceptionError. These errors will propogate down the promise chain till it is
 * handled by an onBroken block.
 */
@interface PromiseZ : NSObject <PZThenable>

/// @name Accessing the promise's future value

/**
 * A container for the future value of the promise
 *
 * This method can either contain the successful result or the failing NSError.
 *
 * @note Checking the type of the result to determine whether the promise has been
 * kept or broken can result in incorrect assumptions. Use the state property or
 * isPending, isKept, isBroken instead.
 */
@property (strong, nonatomic, readonly) id result;


/// @name Checking the promise's state

/**
 * The current state of the promise
 *
 * Available values:
 * - PZPromiseStatePending
 * - PZPromiseStateKept
 * - PZPromiseStateBroken
 */
@property (assign, nonatomic, readonly) PZPromiseState state;

/**
 * Asks the promise if it is pending
 * @return A flag indicating if the promise is still pending
 */
- (BOOL)isPending;

/**
 * Asks the promise if it has been kept
 * @return A flag indicating if the promise was kept
 */
- (BOOL)isKept;

/**
 * Asks the promise if it has been broken
 * @return A flag indicating if the promise was broken
 */
- (BOOL)isBroken;


/// @name Keeping and breaking a promise

/**
 * Attempts to keep the promise with the passed result
 *
 * In order to successfully keep the promise, the promise must be pending
 * and must not be bound. If the promise is bound, then the passed result must
 * be the bindingPromise property's result. If both checks pass, then the
 * promise's state becomes PZPromiseStateKept and it's result property assumes
 * the same value that is passed.
 *
 * @note In the case of a bound promise, the passed value must be the same object
 * as the binding promise's result (i.e. `result1 == result2`, not 
 * `[result1 isEqual:result2]`).
 *
 * @param result The successful value that should become the promise's result
 */
- (void)keepWithResult:(id)result;

/**
 * Attempts to break the promise with the passed reason
 *
 * In order to successfully break the promise, the promise must be pending
 * and must not be bound. If the promise is bound, then the passed reason must be
 * the bindingPromise property's result. If both checks pass, then the promise's
 * state becomes PZPromiseStateBroken and it's result assumes the reason passed.
 *
 * @note In the case of a bound promise, the passed reason must be the same object
 * as the binding promise's result (i.e. `reason == result2`, not
 * `[reason isEqual:result2]`).
 *
 * @param reason The NSError that caused the break
 */
- (void)breakWithReason:(NSError *)reason;


/// @name Binding a promise to another promise

/**
 * A weak reference to a binding promise
 *
 * When a promise is bound this property will be populated with the binding
 * promise. However, the binding promise can be deallocated at any time without
 * ill effects on the promise.
 *
 * @see bindToPromise:, isBound
 */
@property (weak, nonatomic, readonly) PromiseZ *bindingPromise;

/**
 * Asks the promise if it is bound to another promise
 * @return A flag indicating if the promise was bound
 */
- (BOOL)isBound;

/**
 * Attempts to bind the promise to another promise
 *
 * When a promise is successfully bound to another promise (promise2), it will
 * become impervious to keepWithResult: and breakWithReason: unless it is being
 * kept or broken with promise2's result.
 *
 * If a promise has already been bound, it cannot be bound unless it's binding
 * promise is unset.
 *
 * @param promise The promise to bind to
 */
- (void)bindToPromise:(PromiseZ *)promise;


/// @name Managing callbacks

/**
 * Cancels enqueued on kept or on broken callbacks.
 */
- (void)cancelAllCallbacks;

@end
