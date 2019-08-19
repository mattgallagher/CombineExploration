//
//  CustomSubject.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//

import Combine

/// A custom implementation of `PassthroughSubject`
public class CustomSubject<Output, Failure: Error>: Subject, Publisher {
	class Behavior: SubscriptionBehavior {
		typealias Input = Output
		
		var upstream: Subscription? = nil
		let downstream: AnySubscriber<Input, Failure>
		let subject: CustomSubject<Output, Failure>
		var demand: Subscribers.Demand = .none
		
		init(subject: CustomSubject<Output, Failure>, downstream: AnySubscriber<Input, Failure>) {
			self.downstream = downstream
			self.subject = subject
		}

		func request(_ d: Subscribers.Demand) {
			demand += d
			upstream?.request(d)
		}
		
		func cancel() {
			subject.subscribers.mutate { subs in subs.removeValue(forKey: self.combineIdentifier) }
		}
	}

	let subscribers = AtomicBox<Dictionary<CombineIdentifier, CustomSubscription<Behavior>>>([:])
	
	public init() {}
	
	public func send(_ value: Output) {
		for (_, sub) in subscribers.value {
			_ = sub.receive(value)
		}
	}
	
	public func send(subscription: Subscription) {
		subscription.request(.unlimited)
	}
	
	public func send(completion: Subscribers.Completion<Failure>) {
		let set = subscribers.mutate { (subs: inout Dictionary<CombineIdentifier, CustomSubscription<Behavior>>) -> Dictionary<CombineIdentifier, CustomSubscription<Behavior>> in
			let previous = subs
			subs.removeAll()
			return previous
		}

		for (_, sub) in set {
			sub.receive(completion: completion)
		}
	}

	public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
		let behavior = Behavior(subject: self, downstream: AnySubscriber(subscriber))
		let subscription = CustomSubscription(behavior: behavior)
		subscribers.mutate { $0[subscription.combineIdentifier] = subscription }
		subscription.receive(subscription: Subscriptions.empty)
	}
}
