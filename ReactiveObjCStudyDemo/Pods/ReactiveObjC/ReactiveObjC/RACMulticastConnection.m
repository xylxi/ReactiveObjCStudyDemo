//
//  RACMulticastConnection.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACMulticastConnection.h"
#import "RACMulticastConnection+Private.h"
#import "RACDisposable.h"
#import "RACSerialDisposable.h"
#import "RACSubject.h"
#import <libkern/OSAtomic.h>

@interface RACMulticastConnection () {
	RACSubject *_signal;

	// When connecting, a caller should attempt to atomically swap the value of this
	// from `0` to `1`.
	//
	// If the swap is successful the caller is resposible for subscribing `_signal`
	// to `sourceSignal` and storing the returned disposable in `serialDisposable`.
	//
	// If the swap is unsuccessful it means that `_sourceSignal` has already been
	// connected and the caller has no action to take.
	int32_t volatile _hasConnected;
}

@property (nonatomic, readonly, strong) RACSignal *sourceSignal;
@property (strong) RACSerialDisposable *serialDisposable;
@end

@implementation RACMulticastConnection

#pragma mark Lifecycle

- (instancetype)initWithSourceSignal:(RACSignal *)source subject:(RACSubject *)subject {
	NSCParameterAssert(source != nil);
	NSCParameterAssert(subject != nil);

	self = [super init];
    // 原本的RACSignal
	_sourceSignal = source;
	_serialDisposable = [[RACSerialDisposable alloc] init];
    // 本质上是个 RACSubject ，暴露出去的时候是作为 RACSignal 的类型
	_signal = subject;
	
	return self;
}

#pragma mark Connecting

- (RACDisposable *)connect {
	BOOL shouldConnect = OSAtomicCompareAndSwap32Barrier(0, 1, &_hasConnected);

	if (shouldConnect) {
        // 只有在执行 connect 后，_signal(Subject) 才会订阅源信号
        // 这时候，当 sourceSignal 有数据后，让 [_signal sendNext:data];
        // 然后 subject 会遍历所有的订阅者 ，让所有的订阅者执行 [innerSubscriber sendNext:data]
        // 之所以在 connect 后才 subscribe,是为了让 源信号的 didSubscribe 只执行一次。
		self.serialDisposable.disposable = [self.sourceSignal subscribe:_signal];
	}

	return self.serialDisposable;
}

- (RACSignal *)autoconnect {
	__block volatile int32_t subscriberCount = 0;
    // 反正在返回后，第一次被订阅的时候，将 sourceSignal 和 _signal 之间建立联系
	return [[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			OSAtomicIncrement32Barrier(&subscriberCount);

			RACDisposable *subscriptionDisposable = [self.signal subscribe:subscriber];
			RACDisposable *connectionDisposable = [self connect];

			return [RACDisposable disposableWithBlock:^{
				[subscriptionDisposable dispose];

				if (OSAtomicDecrement32Barrier(&subscriberCount) == 0) {
					[connectionDisposable dispose];
				}
			}];
		}]
		setNameWithFormat:@"[%@] -autoconnect", self.signal.name];
}

@end
