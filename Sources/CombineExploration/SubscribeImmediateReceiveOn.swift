//
//  SubscribeImmediateReceiveOn.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//

import Foundation
import Combine

public extension Publisher {
	func subscribeImmediateReceive<S>(on scheduler: S, options: S.SchedulerOptions? = nil) -> SubscribeImmediateReceiveOn<Self, S> where S : Scheduler {
		return SubscribeImmediateReceiveOn(upstream: self, receiveOnScheduler: scheduler, options: options)
	}
}

public struct SubscribeImmediateReceiveOn<Upstream: Publisher, Context: Scheduler>: Publisher {
	public typealias Output = Upstream.Output
	public typealias Failure = Upstream.Failure

	class Behavior: SubscriptionBehavior {
		typealias Input = Upstream.Output
		var upstream: Subscription? = nil
		let downstream: AnySubscriber<Output, Upstream.Failure>
		var demand: Subscribers.Demand = .none
		let context: Context
		let options: Context.SchedulerOptions?
		
		init(downstream: AnySubscriber<Output, Upstream.Failure>, context: Context, options: Context.SchedulerOptions?) {
			self.downstream = downstream
			self.context = context
			self.options = options
		}

		func receive(_ input: Upstream.Output) -> Subscribers.Demand {
			context.schedule(options: options) { [downstream] in
				_ = downstream.receive(input)
			}
			return .unlimited
		}

		func receive(completion: Subscribers.Completion<Failure>) {
			context.schedule(options: options) { [downstream] in
				downstream.receive(completion: completion)
			}
		}
	}
	
	let upstream: Upstream
	let context: Context
	let options: Context.SchedulerOptions?
	public init(upstream: Upstream, receiveOnScheduler: Context, options: Context.SchedulerOptions?) {
		self.upstream = upstream
		self.context = receiveOnScheduler
		self.options = options
	}
	
	public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
		let downstream = AnySubscriber(subscriber)
		let behavior = Behavior(downstream: downstream, context: context, options: options)
		let subscription = CustomSubscription(behavior: behavior)
		upstream.subscribe(subscription)
	}
}
