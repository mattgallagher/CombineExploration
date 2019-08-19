//
//  CustomDemandSink.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//

import Combine

/// A testing-only Subscriber that allows configuring the `demand` from outside. I don't see any practical use for this outside of testing Combine.
public struct CustomDemandSink<Input, Failure: Error>: Subscriber, Cancellable {
	public let combineIdentifier = CombineIdentifier()
	let activeSubscription = AtomicBox<(demand: Int, subscription: Subscription?)>((0, nil))
	let value: (Input) -> Void
	let completion: (Subscribers.Completion<Failure>) -> Void
	
	public init(demand: Int, receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void), receiveValue: @escaping ((Input) -> Void)) {
		value = receiveValue
		completion = receiveCompletion
		activeSubscription.mutate { v in v.demand = demand }
	}
	
	public func increaseDemand(_ value: Int) {
		activeSubscription.mutate {
			$0.subscription?.request(.max(value))
		}
	}
	
	public func receive(subscription: Subscription) {
		activeSubscription.mutate {
			if $0.subscription == nil {
				$0.subscription = subscription
				
				if $0.demand > 0 {
					$0.demand -= 1
					subscription.request(.max(1))
				}
			}
		}
	}

	public func receive(_ input: Input) -> Subscribers.Demand {
		value(input)
		
		var demand = Subscribers.Demand.none
		activeSubscription.mutate {
			if $0.demand > 0 {
				$0.demand -= 1
				demand = .max(1)
			}
		}
		return demand
	}

	public func receive(completion c: Subscribers.Completion<Failure>) {
		completion(c)
		activeSubscription.mutate {
			$0 = (0, nil)
		}
	}
	
	public func cancel() {
		activeSubscription.mutate {
			$0.subscription?.cancel()
			$0 = (0, nil)
		}
	}
}
