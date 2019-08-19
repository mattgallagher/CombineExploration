//
//  MergeSink.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//

import Combine

/// A type that can receive values (but not completion) from an arbitrary number of upstream `Publisher`s.
/// Implemented as a wrapper around a `PassthroughSubject` subscribes to upstream `Publisher`s, owns the subscription internally and removes the
/// upstream `Publisher`s when they complete..
public class MergeInput<I>: Publisher, Cancellable {
	public typealias Output = I
	public typealias Failure = Never
	
	private let subscriptions = AtomicBox(Dictionary<CombineIdentifier, Subscribers.Sink<I, Never>>())
	private let subject = PassthroughSubject<I, Never>()
	
	public init() {}
	
	public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, S.Input == I {
		subject.receive(subscriber: subscriber)
	}
	
	public func subscribe<P>(_ publisher: P) where P: Publisher, P.Output == I, P.Failure == Never{
		var identifer: CombineIdentifier?
		let sink = Subscribers.Sink<I, P.Failure>(
			receiveCompletion: { [subscriptions] _ in _ = subscriptions.mutate { $0.removeValue(forKey: identifer!) } },
			receiveValue: { [subject] value in subject.send(value) }
		)
		identifer = sink.combineIdentifier
		subscriptions.mutate { $0[sink.combineIdentifier] = sink }
		publisher.subscribe(sink)
	}
	
	public func cancel() {
		subscriptions.mutate {
			$0.values.forEach { $0.cancel() }
			$0.removeAll()
		}
	}
	
	public func send(_ value: I) {
		subject.send(value)
	}
	
	deinit {
		cancel()
	}
}

public extension Publisher where Failure == Never {
	func merge(into mergeInput: MergeInput<Output>) {
		mergeInput.subscribe(self)
	}
}
