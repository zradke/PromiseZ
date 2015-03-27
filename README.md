#PromiseZ

[![CI Status](http://img.shields.io/travis/zradke/PromiseZ.svg?style=flat)](https://travis-ci.org/zradke/PromiseZ)
[![Version](https://img.shields.io/cocoapods/v/PromiseZ.svg?style=flat)](http://cocoapods.org/pods/PromiseZ)
[![License](https://img.shields.io/cocoapods/l/PromiseZ.svg?style=flat)](http://cocoapods.org/pods/PromiseZ)
[![Platform](https://img.shields.io/cocoapods/p/PromiseZ.svg?style=flat)](http://cocoapods.org/pods/PromiseZ)

A high level implementation of the [Promises/A+ spec](https://github.com/promises-aplus/promises-spec) which borrows heavily and shamelessly from the [RXPromise implementation](https://github.com/couchdeveloper/RXPromise).

---

## Installation

Cocoapods is a nice dependency manager for iOS and OSX apps. Take a look at the [Cocoapods website](https://github.com/CocoaPods/CocoaPods) to get started if you're not familiar.

Once cocoapods is set up, just add the following to your Podfile:

    pod 'PromiseZ'

And when you're importing the library:

	#import <PromiseZ/PZPromise.h>

## Putting it to use

At its core a promise represents an undetermined result. For example, when making a network request, the data is not available immediately, and the request can either be successful with a result or fail for some reason. Promises represent all those states and potential values in one object.

The `PZPromise` class conforms to the `<PZThenable>` protocol and conforms to the Promises/A+ spec. It can be initialized via the `-init` method.

Let's say we have a method which does some background processing asynchronously:

	- (PZPromise *)doSomethingAsync
	{
		// This promise will need to be retained somehow so it can be notified of it's eventual value or failed reason.
		PZPromise *promise = [PZPromise new];
		...
		return promise;
	}

At the most basic level, we can be notified when the method completes by adding on-kept and on-broken blocks:

	PZPromise *promise = [self doSomethingAsync];
	[promise thenOnKept:^id(id value) {
		// Do something with the result
		...
		return nil; // The return value doesn't matter in this case
	} onBroken:^id(NSError *reason) {
		// Do something to handle the failure
		...
		return nil; // The return value doesn't matter in this case
	}];

Notice that the on-kept and on-broken blocks actualy return a value. That's because the `-thenOnKept:onBroken:` method actually returns another `<PZThenable>`! This new promise is resolved depending on what you return from the on-kept and on-broken blocks, or if you don't provide a block, on the result of the original promise. So in our example let's say we want to do something else with a successful result:

	- (PZPromise *)doSomethingElseAsyncWithResult:(id)result
	{
		...
	}

Instead of returning `nil` from our on-kept block, we can return that promise:

	PZPromise *promiseA = [self doSomethingAsync];
	PZPromise *promiseB = [promise thenOnKept:^id(id value) {
		// We return the next promise we want to execute
		return [self doSomethingElseAsyncWithResult:value];
	} onBroken:^id(NSError *reason) {
		// Do something to handle the failure
		...
		
		// We can return an already broken promise so promiseB will also be broken.
		return [[PZPromise alloc] initWithBrokenReason:reason];
	}];

In this case `promiseB` will resolve whenever the promise returned by `doSomethingElseAsyncWithResult:` resolves.

But in our example we don't realy need `promiseA`, so we can ignore it and start chaining:

	PZPromise *promise = [[self doSomethingAsync] thenOnKept:^id(id value) {
		return [self doSomethingElseAsyncWithResult:value];
	} onBroken:^id(NSError *reason) {
		...
		return [[PZPromise alloc] initWithBrokenReason:reason];
	}];

The returned promise will only be resolved after `-doSomethingAsync` resolves its promise and `-doSomethingElseAsyncWithResult:` resolves. We can continue chaining as long as we need:

	PZPromise *promise = [[[self doSomethingAsync] thenOnKept:^id(id value) {
		return [doSomethingElseAsyncWithResult:value];
	} onBroken:nil] thenOnKept:^id(id value) {
		return [doAnotherThingWithAnotherResult:value];
	} onBroken:nil] thenOnKept:^id(id value) {
		return [doFinalThingWithFinalResult:value];
	} onBroken:^id(NSError *error) {
		// Handle any of the errors that other promises in the chain encountered
		...
		return [[PZPromise alloc] initWithBrokenReason:reason];
	}];

Note that we are passing `nil` for the on-broken block. Remember that both the on-kept and on-broken blocks are optional. If they are `nil`, the promise simply passes on its state and value to the returned promise. In this way, the final on-broken block will actually will catch any of the previous promises' failures! The same would work for on-kept blocks as well.

Promises returned by the `-thenOnKept:onBroken:` method are different from ones created via `-init` or `+new` in that their resolution depends on the initial promise or the block return values. For this reason, they are considered "bound" and **bound promises cannot be manually kept or broken**. Calling `-keepWithValue:` or `-breakWithReason:` on a bound promise will have no effect.

## What's the catch?

The `PZPromise` class represents only part of the promise equation. The other part is that in order for it to be any use, **your async methods must generate, return, keep, and break `PZPromise` instances**. Specific implementations are a bit beyond the scope of this read-me (though you can take a look at the example app for some inspiration), but generally there are a few points to consider:

* When an async method is called, return a pending `PZPromise` instance.
* If the async method resolves in success, call `-keepWithValue:` on the promise, passing the successful result.
* If the async method fails for some reason, call `-breakWithReason:` on the promise, passing an NSError representing the reason.

A key point in this implementation is that the class with the async method needs to keep a hold of its promises and resolve the proper promise with the proper value (success or failure). Once you've got that down, it's all dandy!

---

## Getting into the snickel-frits

Is a high-level overview not enough? This section gets into some more esoteric points about the `PZPromise` implementation.

### Becoming "thenable"
The `<PZThenable>` protocol defines the `-thenOnKept:onBroken:` method which conformers must implement. Though `PZPromise` conforms to the protocol, it is left independent for cases when a method wishes to return a custom object instead of the normal `PZPromise`. Typically, though, the `PZPromise` class should suffice.

### Concurrency
* `PZPromise` should be thread safe, and can be resolved (`-keepWithValue:` or `-breakWithReason:`) on any thread regardless of where they were created.
* As per the Promises/A+ spec, on-kept or on-broken blocks are always executed asynchronously on at least the next run-loop, even if the receiving `PZPromise` has already been kept or broken.
* On-kept and on-broken blocks make no guarantees about what thread they are called on. For this reason, it is important when making UI changes to always dispatch back to the main thread.
