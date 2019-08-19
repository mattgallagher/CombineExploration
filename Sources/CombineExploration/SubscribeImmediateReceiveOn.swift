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
	
	let upstream: Upstream
	let context: Context
	let options: Context.SchedulerOptions?
	public init(upstream: Upstream, receiveOnScheduler: Context, options: Context.SchedulerOptions?) {
		self.upstream = upstream
		self.context = receiveOnScheduler
		self.options = options
	}
	
	public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
		self.upstream.subscribe(Subscribers.Sink<Output, Failure>(
			receiveCompletion: { [context, options] completion in
				context.schedule(options: options) { subscriber.receive(completion: completion) }
			},
			receiveValue: { [context, options] value in
				context.schedule(options: options) { _ = subscriber.receive(value) }
			}
		))
	}
}
