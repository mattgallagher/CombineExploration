//
//  BufferMulticast.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//

import Combine
import Foundation

public struct Buffer<Output, Failure: Error> {
	var values: [Output] = []
	var completion: Subscribers.Completion<Failure>? = nil
	let limit: Int
	let strategy: Publishers.BufferingStrategy<Failure>
	
	public var isEmpty: Bool {
		return values.isEmpty && completion == nil
	}
	
	public mutating func push(_ value: Output) {
		guard completion == nil else { return }
		guard values.count < limit else {
			switch strategy {
			case .dropNewest:
				values.removeLast()
				values.append(value)
			case .dropOldest:
				values.removeFirst()
				values.append(value)
			case .customError(let err):
				completion = .failure(err())
			@unknown default:
				fatalError()
			}
			return
		}
		values.append(value)
	}

	public mutating func push(completion: Subscribers.Completion<Failure>) {
		guard self.completion == nil else { return }
		self.completion = completion
	}
	
	public mutating func pop() -> Subscribers.Event<Output, Failure>? {
		if values.count > 0 {
			return .value(values.removeFirst())
		} else if let completion = self.completion {
			values = []
			self.completion = nil
			return .complete(completion)
		}
		return nil
	}
}

/// A custom implementation of `PassthroughSubject`
public class BufferSubject<Output, Failure: Error>: Subject, Publisher {
	class Behavior: SubscriptionBehavior {
		typealias Input = Output
		
		var upstream: Subscription? = nil
		let downstream: AnySubscriber<Input, Failure>
		let subject: BufferSubject<Output, Failure>
		var demand: Subscribers.Demand = .none
		var buffer: Buffer<Output, Failure>
		
		init(subject: BufferSubject<Output, Failure>, downstream: AnySubscriber<Input, Failure>, buffer: Buffer<Output, Failure>) {
			self.downstream = downstream
			self.subject = subject
			self.buffer = buffer
		}

		func request(_ d: Subscribers.Demand) {
			demand += d
			while demand > 0, let next = buffer.pop() {
				demand -= 1
				switch next {
				case .value(let v):
					let newDemand = downstream.receive(v)
					demand = newDemand + (demand - 1)
				case .complete(let c):
					downstream.receive(completion: c)
				}
			}
		}

		func receive(_ input: Input) -> Subscribers.Demand {
			if demand > 0 && buffer.isEmpty {
				let newDemand = downstream.receive(input)
				demand = newDemand + (demand - 1)
			} else {
				buffer.push(input)
			}
			return Subscribers.Demand.unlimited
		}
		
		func receive(completion: Subscribers.Completion<Failure>) {
			if buffer.isEmpty {
				downstream.receive(completion: completion)
			} else {
				buffer.push(completion: completion)
			}
		}
		
		func cancel() {
			subject.subscribers.mutate { subs in subs.removeValue(forKey: self.combineIdentifier) }
		}
	}

	let subscribers = AtomicBox<Dictionary<CombineIdentifier, CustomSubscription<Behavior>>>([:])
	let buffer: AtomicBox<Buffer<Output, Failure>>
	
	public init(limit: Int = 1, whenFull strategy: Publishers.BufferingStrategy<Failure> = .dropOldest) {
		precondition(limit >= 0)
		buffer = AtomicBox(Buffer(limit: limit, strategy: strategy))
	}
	
	public func send(_ value: Output) {
		buffer.mutate { b in
			b.push(value)
		}
		for (_, sub) in subscribers.value {
			_ = sub.receive(value)
		}
	}
	
	public func send(subscription: Subscription) {
		subscription.request(.unlimited)
	}
	
	public func send(completion: Subscribers.Completion<Failure>) {
		buffer.mutate { b in
			b.push(completion: completion)
		}
		
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
		let behavior = Behavior(subject: self, downstream: AnySubscriber(subscriber), buffer: buffer.value)
		let subscription = CustomSubscription(behavior: behavior)
		subscribers.mutate { $0[subscription.combineIdentifier] = subscription }
		subscription.receive(subscription: Subscriptions.empty)
	}
}
