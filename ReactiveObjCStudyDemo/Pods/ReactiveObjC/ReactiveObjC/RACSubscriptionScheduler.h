//
//  RACSubscriptionScheduler.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

NS_ASSUME_NONNULL_BEGIN

// A private scheduler used only for subscriptions. See the private
// +[RACScheduler subscriptionScheduler] method for more information.
// 所有 ReactiveCocoa 中的订阅事件都会在 RACSubscriptionScheduler 调度器上进行
// 负责将任务交给当前线程或者后台线程
@interface RACSubscriptionScheduler : RACScheduler

@end

NS_ASSUME_NONNULL_END
