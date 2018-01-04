//
//  RACCommand.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import <ReactiveObjC/RACEXTScope.h>
#import "NSArray+RACSequenceAdditions.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignal+Operations.h"
#import <libkern/OSAtomic.h>

NSString * const RACCommandErrorDomain = @"RACCommandErrorDomain";
NSString * const RACUnderlyingCommandErrorKey = @"RACUnderlyingCommandErrorKey";

const NSInteger RACCommandErrorNotEnabled = 1;

@interface RACCommand () {
	// Atomic backing variable for `allowsConcurrentExecution`.
	volatile uint32_t _allowsConcurrentExecution;
}

/// A subject that sends added execution signals.
/// 很重要的 RACSubject 的对象 发送添加的执行信号的Subject
///
@property (nonatomic, strong, readonly) RACSubject *addedExecutionSignalsSubject;

/// A subject that sends the new value of `allowsConcurrentExecution` whenever it changes.
@property (nonatomic, strong, readonly) RACSubject *allowsConcurrentExecutionSubject;

// `enabled`, but without a hop to the main thread.
//
// Values from this signal may arrive on any thread.
@property (nonatomic, strong, readonly) RACSignal *immediateEnabled;

// The signal block that the receiver was initialized with.
@property (nonatomic, copy, readonly) RACSignal * (^signalBlock)(id input);

@end

@implementation RACCommand

#pragma mark Properties

- (BOOL)allowsConcurrentExecution {
	return _allowsConcurrentExecution != 0;
}

- (void)setAllowsConcurrentExecution:(BOOL)allowed {
	if (allowed) {
		OSAtomicOr32Barrier(1, &_allowsConcurrentExecution);
	} else {
		OSAtomicAnd32Barrier(0, &_allowsConcurrentExecution);
	}

	[self.allowsConcurrentExecutionSubject sendNext:@(_allowsConcurrentExecution)];
}

#pragma mark Lifecycle

- (instancetype)init {
	NSCAssert(NO, @"Use -initWithSignalBlock: instead");
	return nil;
}

- (instancetype)initWithSignalBlock:(RACSignal<id> * (^)(id input))signalBlock {
	return [self initWithEnabled:nil signalBlock:signalBlock];
}

- (void)dealloc {
	[_addedExecutionSignalsSubject sendCompleted];
	[_allowsConcurrentExecutionSubject sendCompleted];
}

- (instancetype)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal<id> * (^)(id input))signalBlock {
	NSCParameterAssert(signalBlock != nil);

	self = [super init];

	_addedExecutionSignalsSubject = [RACSubject new];
	_allowsConcurrentExecutionSubject = [RACSubject new];
	_signalBlock = [signalBlock copy];

    // 高阶信号量 可以使用flatten，switchToLatest，concat进行降阶
	_executionSignals = [[[self.addedExecutionSignalsSubject
		map:^(RACSignal *signal) {
            // 将信号中的所有的错误 NSError 转换成了 RACEmptySignal 对象，并派发到主线程上
			return [signal catchTo:[RACSignal empty]];
		}]
		deliverOn:RACScheduler.mainThreadScheduler]
		setNameWithFormat:@"%@ -executionSignals", self];
	
	// `errors` needs to be multicasted so that it picks up all
	// `activeExecutionSignals` that are added.
	//
	// In other words, if someone subscribes to `errors` _after_ an execution
	// has started, it should still receive any error from that execution.
	RACMulticastConnection *errorsConnection = [[[self.addedExecutionSignalsSubject
		flattenMap:^(RACSignal *signal) {
			return [[signal
				ignoreValues]
				catch:^(NSError *error) {
					return [RACSignal return:error];
				}];
		}]
		deliverOn:RACScheduler.mainThreadScheduler]
		publish];
	
	_errors = [errorsConnection.signal setNameWithFormat:@"%@ -errors", self];
	[errorsConnection connect];

    // 是一个用于表示当前是否有任务执行的信号
	RACSignal *immediateExecuting = [[[[self.addedExecutionSignalsSubject
		flattenMap:^(RACSignal *signal) {
            // 将每一个信号的开始和结束的时间点转换成 1 和 -1 两个信号；
			return [[[signal // 当这个signal执行结束==> complete或者error时候==>then==>-1
				catchTo:[RACSignal empty]]
				then:^{// 忽略signal的所有values，用于连接两个信号，当第一个信号(signal)完成，才会连接then返回的信号。并且只会拿到then后面的信号量发送的数据-1
					return [RACSignal return:@-1];
				}]
				startWith:@1]; // 当开始发送的时候，先发送 1
		}]
		scanWithStart:@0 reduce:^(NSNumber *running, NSNumber *next) {
			return @(running.integerValue + next.integerValue);
		}]
		map:^(NSNumber *count) {
			return @(count.integerValue > 0);
		}]
		startWith:@NO];// 信号 immediateExecuting 的开始值为 NO

	_executing = [[[[[immediateExecuting
		deliverOn:RACScheduler.mainThreadScheduler]
		// This is useful before the first value arrives on the main thread.
		startWith:@NO]
		distinctUntilChanged]
		replayLast] // 到这一步才是真的对immediateExecuting的订阅
		setNameWithFormat:@"%@ -executing", self];
	
	RACSignal *moreExecutionsAllowed = [RACSignal
		if:[self.allowsConcurrentExecutionSubject startWith:@NO]
		then:[RACSignal return:@YES]
		else:[immediateExecuting not]];// 如果不支持并发，就是跟 immediateExecuting 取反
	
	if (enabledSignal == nil) {
        // 发送 @YES 的信号量
		enabledSignal = [RACSignal return:@YES];
	} else {
		enabledSignal = [enabledSignal startWith:@YES];
	}
	
	_immediateEnabled = [[[[RACSignal
		combineLatest:@[ enabledSignal, moreExecutionsAllowed ]] // 将最新的两个信号量组合
		and] // & 操作
		takeUntil:self.rac_willDeallocSignal]
		replayLast]; // 缓存最新状态
	
    // 于 __executing 没有什么区别，信号流中的第一个值会在订阅线程上到达，剩下的所有的值都会在主线程上派发
	_enabled = [[[[[self.immediateEnabled
		take:1]
		concat:[[self.immediateEnabled skip:1] deliverOn:RACScheduler.mainThreadScheduler]]
		distinctUntilChanged]
		replayLast]
		setNameWithFormat:@"%@ -enabled", self];

	return self;
} 

#pragma mark Execution

- (RACSignal *)execute:(id)input {
	// `immediateEnabled` is guaranteed to send a value upon subscription, so
	// -first is acceptable here.
    // 取当前一个bool值
	BOOL enabled = [[self.immediateEnabled first] boolValue];
	if (!enabled) {
		NSError *error = [NSError errorWithDomain:RACCommandErrorDomain code:RACCommandErrorNotEnabled userInfo:@{
			NSLocalizedDescriptionKey: NSLocalizedString(@"The command is disabled and cannot be executed", nil),
			RACUnderlyingCommandErrorKey: self
		}];

		return [RACSignal error:error];
	}

	RACSignal *signal = self.signalBlock(input);
	NSCAssert(signal != nil, @"nil signal returned from signal block for value: %@", input);

	// We subscribe to the signal on the main thread so that it occurs _after_
	// -addActiveExecutionSignal: completes below.
	//
	// This means that `executing` and `enabled` will send updated values before
	// the signal actually starts performing work.
    // 注意subscribeOn: 这个地方
    // 效果就是 didSubscriber() 放在了主队列中 dispath_async(self.queue,block)
    // 信号真正订阅在函数返回之后
    // 因为队列的先进先出的特性
	RACMulticastConnection *connection = [[signal
		subscribeOn:RACScheduler.mainThreadScheduler]
		multicast:[RACReplaySubject subject]];
	
	[self.addedExecutionSignalsSubject sendNext:connection.signal];
    // 执行 signal 的原有的 didSubscribe
	[connection connect];
	return [connection.signal setNameWithFormat:@"%@ -execute: %@", self, RACDescription(input)];
}

@end
