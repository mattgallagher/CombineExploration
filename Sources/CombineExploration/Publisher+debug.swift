//
//  Publisher+debug.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//

import Combine

public extension Publisher {
	func debug(prefix: String = "", function: String = #function, line: Int = #line) -> Publishers.HandleEvents<Self> {
		let pattern = "\(prefix + (prefix.isEmpty ? "" : " "))\(function), line \(line): "
		return handleEvents(
			receiveSubscription: { Swift.print("\(pattern)subscription \($0)") },
			receiveOutput: { Swift.print("\(pattern)output \($0)") },
			receiveCompletion: { Swift.print("\(pattern)completion \($0)") },
			receiveCancel: { Swift.print("\(pattern)cancelled") },
			receiveRequest: { Swift.print("\(pattern)request \($0)") }
		)
	}
}
