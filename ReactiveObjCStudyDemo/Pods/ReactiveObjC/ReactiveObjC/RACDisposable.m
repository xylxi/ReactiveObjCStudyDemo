//
//  RACDisposable.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDisposable.h"
#import "RACScopedDisposable.h"
#import <libkern/OSAtomic.h>

@interface RACDisposable () {
	// A copied block of type void (^)(void) containing the logic for disposal,
	// a pointer to `self` if no logic should be performed upon disposal, or
	// NULL if the receiver is already disposed.
	//
	// This should only be used atomically.
    
    /**
     *  类型类似于：@property (copy) void (^disposeBlock)(void);
     *  在 disposal 要执行的任务逻辑。
     *  1、如果没有初始值的话，则初始值默认为 `self`
     *  2、当已经 disposal 过后，值为 NULL。
     *  3、关于 volatile 和 OSMemoryBarrier
     *  http://www.jianshu.com/p/709173eb5fd6
     */
	void * volatile _disposeBlock;
}

@end

@implementation RACDisposable

#pragma mark Properties

- (BOOL)isDisposed {
	return _disposeBlock == NULL;
}

#pragma mark Lifecycle

- (instancetype)init {
	self = [super init];

	_disposeBlock = (__bridge void *)self;
	OSMemoryBarrier();

	return self;
}

- (instancetype)initWithBlock:(void (^)(void))block {
	NSCParameterAssert(block != nil);

	self = [super init];

	_disposeBlock = (void *)CFBridgingRetain([block copy]); 
	OSMemoryBarrier();

	return self;
}

+ (instancetype)disposableWithBlock:(void (^)(void))block {
	return [[self alloc] initWithBlock:block];
}

- (void)dealloc {
	if (_disposeBlock == NULL || _disposeBlock == (__bridge void *)self) return;

	CFRelease(_disposeBlock);
	_disposeBlock = NULL;
}

#pragma mark Disposal

- (void)dispose {
	void (^disposeBlock)(void) = NULL;

	while (YES) {
		void *blockPtr = _disposeBlock;
        // 比较blockPtr和&_disposeBlock是否指向同一内存地址
        // 如果是将返回YES
        // 将 &_disposeBlock 置为新值 NULL
		if (OSAtomicCompareAndSwapPtrBarrier(blockPtr, NULL, &_disposeBlock)) {
			if (blockPtr != (__bridge void *)self) {
                // 确保释放在线程安全的情况下是否 _disposeBlock 
				disposeBlock = CFBridgingRelease(blockPtr);
			}

			break;
		}
	}

	if (disposeBlock != nil) disposeBlock();
}

#pragma mark Scoped Disposables

- (RACScopedDisposable *)asScopedDisposable {
	return [RACScopedDisposable scopedDisposableWithDisposable:self];
}

@end
