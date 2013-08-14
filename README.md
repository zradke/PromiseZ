#PromiseZ
A high level implementation of the [Promises/A+ spec](https://github.com/promises-aplus/promises-spec) which borrows heavily and shamelessly from the [RXPromise implementation](https://github.com/couchdeveloper/RXPromise).

---

#Getting set up
There are a few different installation options, ordered here from least to most complex (as far as I can tell).

* Drag-n-drop
* ~~Cocoapods~~ (Currently unavailable)
* Build framework

##Drag-n-drop
PromiseZ is really just two files: **PromiseZ.h** and **PromiseZ.m**. You can clone this repo, and simply drag those two files into your Xcode project. Make sure the "Copy items into destination group's folder (if needed)" checkbox is checked, and your main project target is checked, and that none of the names clash.

##Cocoapods
Cocoapods is a nice dependency manager for iOS and OSX apps. Take a look at the [Cocoapods website](https://github.com/CocoaPods/CocoaPods) to get started if you're not familiar.

Once cocoapods is set up, just add…

```
pod 'PromiseZ'
```

to your Podfile and run `pod install` from the command line!

##Build framework
If you really like frameworks for some reason, you can clone this repo and change the scheme to `PromiseZ-iOS-Universal` or `PromiseZ-OSX` (depending on which platform you are running on). You may need to change the configuration if you want a `Release` version. After that, run the scheme. In the `Products` folder you should see some things with black text. Right click and choose `Show in Finder` to easily get to the build directory. If all the products are red, then navigate to the derived data folder (probably easiest through the Organizer). There you should see a **PromiseZ.framework** folder which you can drag and drop into your project.

Having trouble finding the framework? Here are the paths from the PromiseZ derived data folder depending on the scheme used:

* iOS: `Build/Products/<Configuration>-<iphone…>/PromiseZ.framework`
* OSX: `Build/Products/<Configuration>/PromiseZ.framework`

---

#Putting it to use

##What is it good for?
At its core a promise represents an undetermined result. For example, when making a network request, the data is not available immediately, and the request can either be successful with a result or fail for some reason. Promises represent all those states and potential values in one object.

##What's the catch?
The PromiseZ framework and object represent only the promise part of the equation. The other part is that in order for it to be any use, **your async methods must generate, return, keep, and break PromiseZ**. See the section on being a PromiseZ provider for more info on that!

##How do I work with a PromiseZ?
First, you'll need to get a hold of one from some method. Then, you can use the `thenOnKept:orOnBroken:` method on that PromiseZ to indicate actions that should take place when the promise is kept or broken. What's more, `thenOnKept:orOnBroken:` will also return *another* PromiseZ which you can put more `thenOnKept:orOnBroken:` conditions on! 

Let's see an example:

```
PromiseZ *promise1 = [self doSomethingAsync];
PromiseZ *promise2 = [promise1 thenOnKept:^id(id result) {
	// Do something with result
} orOnBroken:^id(NSError *reason) {
	// Handle the error
}];
```

It's important to note that you don't have to pass an on-kept or on-broken block if you don't want to. The successful result or failure reason will trickle down the chain until a promise does handle it with a block, or into nothingness if no one handles it.

For even more flexibility, you can choose to return something from an on-kept or on-broken block. These return values will be used to resolve the returned promise. Confusing, right? 

Let's see an example:

```
PromiseZ *originalPromise = [self doSomethingAsync];
PromiseZ *returnedPromise = [originalPromise thenOnKept:^id(id result) {
	PromiseZ *otherPromise = [self doAnotherAsyncOperationWithValue:result];
	return otherPromise;
} orOnFailure:nil];
```
In this example, `otherPromise` is returned in the on-kept block, which means that `returnedPromise` will automatically be kept or broken when `otherPromise` is kept or broken. You don't have to return just PromiseZ either, any value will work!

As a last note, **handler blocks are not invoked on the main queue**. This means that performing UI changes in handler blocks (like reloading table views, etc.) can result in strange behavior unless you dispatch those changes on the main queue using GCD or NSOperationQueue.

For example:

```
PromiseZ *returnPromise = [[self doSomethingAsync] thenOnSuccess:^id(id result) {
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		[tableView reloadData];
	}];
	return nil;
} orOnFailure:nil];
```

##C-c-c-combo!
Because `thenOnKept:orOnBroken:` returns another PromiseZ, you can chain together a bunch of dependent tasks. Also, because results and failures will trickle down until they are caught, you can create a single on-broken block to catch any failures at any point in the chain!

Let's rewrite the previous example to take advantage of chaining:

```
PromiseZ *finalPromise = [[[self doSomethingAsync] thenOnKept:^id(id result) {
	return [self doAnotherAsyncOperationWithValue:result];
} orOnBroken:nil] thenOnKept:^id(id result) {
	return [self doFinalAsyncOperationWithValue:result];
} orOnBroken:^id(NSError *reason) {
	// Do some sort of error handling
	NSLog(@"Error: %@", [reason localizedDescription]);
}];
```

##Being a PromiseZ provider
PromiseZ are only useful if they are used by your asynchronous methods. Specific implementations are a bit beyond the scope of this read-me, but generally there are a few points to consider:

* When an async method is called, return a PromiseZ object
* If the async method resolves in success, call `keepWithResult:` on the promise, passing the successful result.
* If the async method fails for some reason, call `breakWithReason:` on the promise, passing an NSError representing the reason.

A key point in this implementation is that the class with the async method needs to keep a hold of its promises and resolve the proper promise with the proper value (success or failure). Once you've got that down, it's all dandy!

---

#Getting into the snickel-frits
Is a high-level overview not enough? This section gets into some more esoteric points about the PromiseZ implementation

##Becoming "thenable"
The PZThenable protocol defines the `thenOnKept:orOnBroken:` method which conformers must implement. PromiseZ naturally adopts this protocol, but it is left exposed separately for cases when a method wishes to return a custom object instead of the normal PromiseZ. Typically, though, the PromiseZ class should suffice.

##Concurrency
* PromiseZ each have an NSOperationQueue which enqueues the handler blocks from `thenOnKept:orOnFailure:`
* Handler blocks are executed on whatever dispatch queue the handler queue provides. Thus to perform UI changes, you should dispatch to the main queue using GCD or NSOperationQueues.
* Promise resolutions (`keepWithResult:` or `breakWithReason`) are synchronized to self
* No synchronization guarantees are placed on retrieving the result or state of PromiseZ (i.e. all properties are nonatomic)

##Guarantees
* A promise will be pending, kept, or broken, but never more than one
* A promise will resolve enqueued blocks from `thenOnKept:orOnBroken:` in the order they are added
* A promise will catch exceptions thrown in a handler block
* A promise will stop infinite resolution recursion caused by a `<PZThenable>` if the recursion depth is past 30
* A bound promise will not respond to `keepWithResult:` or `breakWithReason:` unless the result/reason is the exact object which the binding promise was resolved with.

##Testing
This library/class/framework was unit tested using [Kiwi](https://github.com/allending/Kiwi/). If you would like to run the tests yourself, simply clone this repo and in Xcode change the scheme to `PromiseZ-iOS` or `PromiseZ-OSX` and from the top menu select `Product/Test` or use the shortcut `CMD+U`.
