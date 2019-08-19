//
//  Subscribers.Event.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//


import Combine

/// An "either" type around the possible values 
public extension Subscribers {
	enum Event<Value, Failure: Error> {
		case value(Value)
		case complete(Subscribers.Completion<Failure>)
	}
}

extension Subscribers.Event: Equatable where Value: Equatable, Failure: Equatable {
}

public extension Subscribers.Event {
	var isComplete: Bool {
		switch self {
		case .complete: return true
		default: return false
		}
	}
}

public extension Sequence {
	func asCombineArray(completion: Subscribers.Completion<Never>? = nil) -> Array<Subscribers.Event<Element, Never>> {
		return asCombineArray(failure: Never.self, completion: completion)
	}

	func asCombineArray<Failure>(failure: Failure.Type, completion: Subscribers.Completion<Failure>? = nil) -> Array<Subscribers.Event<Element, Failure>> {
		let values = map(Subscribers.Event<Element, Failure>.value)
		guard let completion = completion else { return values }
		return values + [Subscribers.Event<Element, Failure>.complete(completion)]
	}
}
