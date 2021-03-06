//
//  RACChannel.m
//  ReactiveObjC
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACChannel.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"

@interface RACChannelTerminal ()

// The values for this terminal.
@property (nonatomic, strong, readonly) RACSignal *values;

// A subscriber will will send values to the other terminal.
@property (nonatomic, strong, readonly) id<RACSubscriber> otherTerminal;

- (instancetype)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal;

@end

@implementation RACChannel

- (instancetype)init {
	self = [super init];

	// We don't want any starting value from the leadingSubject, but we do want
	// error and completion to be replayed.
	RACReplaySubject *leadingSubject = [[RACReplaySubject replaySubjectWithCapacity:0] setNameWithFormat:@"leadingSubject"];
	RACReplaySubject *followingSubject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"followingSubject"];

	// Propagate errors and completion to everything.
    // 我们并不希望 leadingSubject 有任何的初始值，但是我们需要 error 和 completed 信息可以被重播。
	[[leadingSubject ignoreValues] subscribe:followingSubject];
	[[followingSubject ignoreValues] subscribe:leadingSubject];

	_leadingTerminal = [[[RACChannelTerminal alloc] initWithValues:leadingSubject otherTerminal:followingSubject] setNameWithFormat:@"leadingTerminal"];
	_followingTerminal = [[[RACChannelTerminal alloc] initWithValues:followingSubject otherTerminal:leadingSubject] setNameWithFormat:@"followingTerminal"];

	return self;
}

@end

@implementation RACChannelTerminal

#pragma mark Lifecycle

- (instancetype)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal {
	NSCParameterAssert(values != nil);
	NSCParameterAssert(otherTerminal != nil);

	self = [super init];
    // 当前端点
	_values = values;
    // 远程端点
	_otherTerminal = otherTerminal;
    
	return self;
}

#pragma mark RACSignal
// 重写subscribe:方法
- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.values subscribe:subscriber];
}

#pragma mark <RACSubscriber>
// 使用self.otherTerminal导致，订阅当前端点(self.values)的订阅者不会收到订阅
- (void)sendNext:(id)value {
	[self.otherTerminal sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.otherTerminal sendError:error];
}

- (void)sendCompleted {
	[self.otherTerminal sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACCompoundDisposable *)disposable {
	[self.otherTerminal didSubscribeWithDisposable:disposable];
}

@end
