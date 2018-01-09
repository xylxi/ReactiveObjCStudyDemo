//
//  RACTargetQueueScheduler.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 6/6/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTargetQueueScheduler.h"
#import "RACQueueScheduler+Subclass.h"

@implementation RACTargetQueueScheduler

#pragma mark Lifecycle

- (instancetype)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue {
	NSCParameterAssert(targetQueue != NULL);

	if (name == nil) {
		name = [NSString stringWithFormat:@"org.reactivecocoa.ReactiveObjC.RACTargetQueueScheduler(%s)", dispatch_queue_get_label(targetQueue)];
	}
    // 创建一个串行队列
	dispatch_queue_t queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_SERIAL);
	if (queue == NULL) return nil;
    // https://www.jianshu.com/p/1945f4b8b203
    // dispatch_set_target_queue 函数有两个作用：
    // 第一，变更队列的执行优先级
    // 第二，目标队列可以成为原队列的执行阶层。
    // 第一个参数是要执行变更的队列（不能指定主队列和全局队列）
    // 第二个参数是目标队列（指定全局队列）
	dispatch_set_target_queue(queue, targetQueue);

	return [super initWithName:name queue:queue];
}

@end
