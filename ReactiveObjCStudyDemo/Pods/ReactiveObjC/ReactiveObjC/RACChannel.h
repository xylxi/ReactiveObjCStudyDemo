//
//  RACChannel.h
//  ReactiveObjC
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSubscriber.h"

@class RACChannelTerminal;

NS_ASSUME_NONNULL_BEGIN

/// A two-way channel.
///
/// Conceptually, RACChannel can be thought of as a bidirectional connection,
/// composed of two controllable signals that work in parallel.
///
/// For example, when connecting between a view and a model:
///
///        Model                      View
///  `leadingTerminal` ------> `followingTerminal`
///  `leadingTerminal` <------ `followingTerminal`
///
/// The initial value of the model and all future changes to it are _sent on_ the
/// `leadingTerminal`, and _received by_ subscribers of the `followingTerminal`.
///
/// Likewise, whenever the user changes the value of the view, that value is sent
/// on the `followingTerminal`, and received in the model from the
/// `leadingTerminal`. However, the initial value of the view is not received
/// from the `leadingTerminal` (only future changes).
@interface RACChannel : NSObject

/// The terminal which "leads" the channel, by sending its latest value
/// immediately to new subscribers of the `followingTerminal`.
///
/// New subscribers to this terminal will not receive a starting value, but will
/// receive all future values that are sent to the `followingTerminal`.
//  对模型进行的操作最后都会发送给 leadingTerminal 再通过内部的实现发送给 followingTerminal  由于视图是 followingTerminal 的订阅者，所以消息最终会发送到视图上。
@property (nonatomic, strong, readonly) RACChannelTerminal *leadingTerminal;

/// The terminal which "follows" the lead of the other terminal, only sending
/// _future_ values to the subscribers of the `leadingTerminal`.
///
/// The latest value sent to the `leadingTerminal` (if any) will be sent
/// immediately to new subscribers of this terminal, and then all future values
/// as well.
//  RACChannel 的绑定都是双向的，视图收到用户的动作，例如点击等事件时，会将消息发送给 followingTerminal，而 followingTerminal 并不会将消息发送给自己的订阅者（视图），而是会发送给 leadingTerminal，并通过 leadingTerminal 发送给其订阅者，即模型。
@property (nonatomic, strong, readonly) RACChannelTerminal *followingTerminal;

@end

/// Represents one end of a RACChannel.
///
/// An terminal is similar to a socket or pipe -- it represents one end of
/// a connection (the RACChannel, in this case). Values sent to this terminal
/// will _not_ be received by its subscribers. Instead, the values will be sent
/// to the subscribers of the RACChannel's _other_ terminal.
///
/// For example, when using the `followingTerminal`, _sent_ values can only be
/// _received_ from the `leadingTerminal`, and vice versa.
///
/// To make it easy to terminate a RACChannel, `error` and `completed` events
/// sent to either terminal will be received by the subscribers of _both_
/// terminals.
///
/// Do not instantiate this class directly. Create a RACChannel instead.
@interface RACChannelTerminal : RACSignal <RACSubscriber>

- (instancetype)init __attribute__((unavailable("Instantiate a RACChannel instead")));

@end

NS_ASSUME_NONNULL_END
