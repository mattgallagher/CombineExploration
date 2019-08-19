//
//  CustomSubscription.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//

import Foundation
import Combine

/// A custom `Subscription` implementation
/// This implementation is just a mutex wrapper around the underlying `SubscriptionBehavior` that does all the real work.
/// However, it is this wrapper which should be passed to other objects (to avoid breaching thread safety).
public struct CustomSubscription<Content: SubscriptionBehavior>: Subscriber, Subscription {
	public typealias Input = Content.Input
	public typealias Failure = Content.Failure
	
	public var combineIdentifier: CombineIdentifier { return content.combineIdentifier }
	let recursiveMutex = NSRecursiveLock()
	let content: Content
	
	init(behavior: Content) {
		self.content = behavior
	}
	
	public func request(_ demand: Subscribers.Demand) {
		recursiveMutex.lock()
		defer { recursiveMutex.unlock() }
		content.request(demand)
	}

	public func cancel() {
		recursiveMutex.lock()
		content.cancel()
		recursiveMutex.unlock()
	}

	public func receive(subscription upstream: Subscription) {
		recursiveMutex.lock()
		defer { recursiveMutex.unlock() }
		content.upstream = upstream
		content.downstream.receive(subscription: self)
	}
	
	public func receive(_ input: Input) -> Subscribers.Demand {
		recursiveMutex.lock()
		defer { recursiveMutex.unlock() }
		return content.receive(input)
	}
	
	public func receive(completion: Subscribers.Completion<Failure>) {
		recursiveMutex.lock()
		defer { recursiveMutex.unlock() }
		content.receive(completion: completion)
	}
}

/// A protocol that can be implemented in a custom `Publisher` to give behavior to its `Subscription`
public protocol SubscriptionBehavior: class, Cancellable, CustomCombineIdentifierConvertible {
	associatedtype Input
	associatedtype Failure: Error
	associatedtype Output
	associatedtype OutputFailure: Error

	var demand: Subscribers.Demand { get set }
	var upstream: Subscription? { get set }
	var downstream: AnySubscriber<Output, OutputFailure> { get }
	
	func request(_ d: Subscribers.Demand)
	func receive(_ input: Input) -> Subscribers.Demand
	func receive(completion: Subscribers.Completion<Failure>)
}

public extension SubscriptionBehavior {
	func request(_ d: Subscribers.Demand) {
		demand += d
		upstream?.request(d)
	}
	func cancel() {
		upstream?.cancel()
	}
}

public extension SubscriptionBehavior where Input == Output, Failure == OutputFailure {
	func receive(_ input: Input) -> Subscribers.Demand {
		if demand > 0 {
			let newDemand = downstream.receive(input)
			demand = newDemand + (demand - 1)
			return newDemand
		}
		return Subscribers.Demand.none
	}
}

public extension SubscriptionBehavior where Failure == OutputFailure {
	func receive(completion: Subscribers.Completion<Failure>) {
		downstream.receive(completion: completion)
	}
}
