//
//  File.swift
//  
//
//  Created by Matt Gallagher on 5/8/19.
//

import Combine

/// A custom implementation of `Publishers.Scan`
public class CustomScan<Upstream: Publisher, Output>: Publisher {
	public typealias Failure = Upstream.Failure
	
	class Behavior: SubscriptionBehavior {
		typealias Input = Upstream.Output
		var upstream: Subscription? = nil
		let downstream: AnySubscriber<Output, Upstream.Failure>
		var demand: Subscribers.Demand = .none
		let reducer: (Output, Upstream.Output) -> Output
		var state: Output
		
		init(downstream: AnySubscriber<Output, Upstream.Failure>, reducer: @escaping (Output, Upstream.Output) -> Output, initialState: Output) {
			self.downstream = downstream
			self.reducer = reducer
			self.state = initialState
		}

		func receive(_ input: Upstream.Output) -> Subscribers.Demand {
			state = reducer(state, input)
			return downstream.receive(state)
		}
	}

	let reducer: (Output, Upstream.Output) -> Output
	let upstream: Upstream
	let initialState: Output
	
	public init(upstream: Upstream, initialResult: Output, nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
		self.initialState = initialResult
		self.reducer = nextPartialResult
		self.upstream = upstream
	}
	
	public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
		let downstream = AnySubscriber(subscriber)
		let behavior = Behavior(downstream: downstream, reducer: reducer, initialState: initialState)
		let subscription = CustomSubscription(behavior: behavior)
		upstream.subscribe(subscription)
	}
}
