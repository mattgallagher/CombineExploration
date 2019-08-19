//
//  CustomSink.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//

import Combine

/// A custom implementation of `Subscribers.Sink`
public struct CustomSink<Input, Failure: Error>: Subscriber, Cancellable {
	public let combineIdentifier = CombineIdentifier()
	let activeSubscription = AtomicBox<Subscription?>(nil)
	let value: (Input) -> Void
	let completion: (Subscribers.Completion<Failure>) -> Void
	
	public init(receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void), receiveValue: @escaping ((Input) -> Void)) {
		value = receiveValue
		completion = receiveCompletion
	}
	
	public func receive(subscription: Subscription) {
		activeSubscription.mutate {
			if $0 == nil {
				$0 = subscription
				subscription.request(.unlimited)
			}
		}
	}

	public func receive(_ input: Input) -> Subscribers.Demand {
		value(input)
		return .unlimited
	}

	public func receive(completion c: Subscribers.Completion<Failure>) {
		completion(c)
		activeSubscription.mutate {
			$0 = nil
		}
	}
	
	public func cancel() {
		activeSubscription.mutate {
			$0?.cancel()
			$0 = nil
		}
	}
}
