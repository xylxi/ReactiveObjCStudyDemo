//
//  RACDisposable.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACScopedDisposable;

NS_ASSUME_NONNULL_BEGIN

/// A disposable encapsulates the work necessary to tear down and cleanup a
/// subscription. 封装了删除和清理订阅需要的工作的disposable
@interface RACDisposable : NSObject

/// Whether the receiver has been disposed. 接收方是否已经被清理
///
/// Use of this property is discouraged, since it may be set to `YES`
/// concurrently at any time.
///
/// This property is not KVO-compliant.
@property (atomic, assign, getter = isDisposed, readonly) BOOL disposed;

+ (instancetype)disposableWithBlock:(void (^)(void))block;

/// Performs the disposal work. Can be called multiple times, though subsequent
/// calls won't do anything.
- (void)dispose;

/// Returns a new disposable which will dispose of this disposable when it gets
/// dealloc'd.
- (RACScopedDisposable *)asScopedDisposable;

@end

NS_ASSUME_NONNULL_END
