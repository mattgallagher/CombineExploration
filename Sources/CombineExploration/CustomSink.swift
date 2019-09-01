//
//  CustomSink.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//

import Combine

public extension Publisher {
	func customSink(receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void), receiveValue: @escaping ((Output) -> Void)) -> AnyCancellable {
		let sink = CustomSink<Output, Failure>(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
		subscribe(sink)
		return AnyCancellable(sink)
	}
}

/// A custom implementation of `Subscribers.Sink`
public struct CustomSink<Input, Failure: Error>: Subscriber, Cancellable {
	enum State {
		case unsubscribed
		case subscribed(Subscription)
		case closed
	}
	
	public let combineIdentifier = CombineIdentifier()
	let activeSubscription = AtomicBox<State>(.unsubscribed)
	let value: (Input) -> Void
	let completion: (Subscribers.Completion<Failure>) -> Void
	
	public init(receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void), receiveValue: @escaping ((Input) -> Void)) {
		value = receiveValue
		completion = receiveCompletion
	}
	
	public func receive(subscription: Subscription) {
		activeSubscription.mutate {
			if case .unsubscribed = $0 {
				$0 = .subscribed(subscription)
				subscription.request(.unlimited)
			}
		}
	}

	public func receive(_ input: Input) -> Subscribers.Demand {
		activeSubscription.mutate {
			if case .subscribed = $0 {
				value(input)
			}
		}
		return .unlimited
	}

	public func receive(completion c: Subscribers.Completion<Failure>) {
		activeSubscription.mutate {
			if case .subscribed = $0 {
				completion(c)
				$0 = .closed
			}
		}
	}
	
	public func cancel() {
		activeSubscription.mutate {
			if case .subscribed(let s) = $0 {
				s.cancel()
			}
			$0 = .closed
		}
	}
}
