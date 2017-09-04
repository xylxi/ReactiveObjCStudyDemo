//
//  RACSubscriber.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"
#import "RACSubscriber+Private.h"
#import <ReactiveObjC/RACEXTScope.h>
#import "RACCompoundDisposable.h"

@interface RACSubscriber ()

// These callbacks should only be accessed while synchronized on self.
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);
// 当订阅者发出 completed 后，就 disposable.isDisposed 为 YES，就不能触发 sendNext 了
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

@end

@implementation RACSubscriber

#pragma mark Lifecycle

+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACSubscriber *subscriber = [[self alloc] init];

	subscriber->_next = [next copy];
	subscriber->_error = [error copy];
	subscriber->_completed = [completed copy];

	return subscriber;
}

- (instancetype)init {
	self = [super init];

	@unsafeify(self);
    
    // 善后工作
	RACDisposable *selfDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self);

		@synchronized (self) {
			self.next = nil;
			self.error = nil;
			self.completed = nil;
		}
	}];

	_disposable = [RACCompoundDisposable compoundDisposable];
	[_disposable addDisposable:selfDisposable];

	return self;
}

- (void)dealloc {
	[self.disposable dispose];
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	@synchronized (self) {
		void (^nextBlock)(id) = [self.next copy];
		if (nextBlock == nil) return;

		nextBlock(value);
	}
}

- (void)sendError:(NSError *)e {
	@synchronized (self) {
		void (^errorBlock)(NSError *) = [self.error copy];
		[self.disposable dispose];

		if (errorBlock == nil) return;
		errorBlock(e);
	}
}

- (void)sendCompleted {
	@synchronized (self) {
		void (^completedBlock)(void) = [self.completed copy];
		[self.disposable dispose];

		if (completedBlock == nil) return;
		completedBlock();
	}
}

// 为了在 dealloc 或者 sendCompleted 后，能够清理 otherDisposable
// 因为在 createSignal: 后，会返回一个 RACDisposable *disposable
// 在 [subscriber sendCompleted] 后能触发 disposable
- (void)didSubscribeWithDisposable:(RACCompoundDisposable *)otherDisposable {
	if (otherDisposable.disposed) return;

	RACCompoundDisposable *selfDisposable = self.disposable;
	[selfDisposable addDisposable:otherDisposable];

	@unsafeify(otherDisposable);

	// If this subscription terminates, purge its disposable to avoid unbounded
	// memory growth.
	[otherDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(otherDisposable);
		[selfDisposable removeDisposable:otherDisposable];
	}]];
}

@end
