#Changes

## 0.2.0 (2015-03-25)

* Rebuilds the framework to work better with Cocoapods and Travis-CI.

##0.1.1 (2013-10-07)

###Enhancements

* Adds example application in the `Example` folder, designed for iOS 7.0
* Adds NSNotifications and better KVO support
* Replaces `@synchronized(self)` with NSRecursiveLock

###Bug fixes

* Fixes bug where chained promises were being released before their parent promise could be resolved.

##0.1.0 (2013-08-14)

* Initial version