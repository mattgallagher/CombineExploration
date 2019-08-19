//
//  ConcurrencyTests.swift
//  CombineExplorationTests
//
//  Created by Matt Gallagher on 21/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//

import XCTest
import Foundation
import Combine
import CombineExploration

class ConcurrencyTests: XCTestCase {
	func testDemand() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let sink = CustomDemandSink<Int, Never>(
			demand: 2,
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		subject.subscribe(sink)
		
		subject.send(sequence: 1...3, completion: nil)
		sink.increaseDemand(2)
		subject.send(sequence: 4...6, completion: .finished)
		
		XCTAssertEqual(received, [1, 2, 4, 5].asCombineArray(completion: .finished))
	}

	func testDeliveryOrder() {
		let sequence = Publishers.Sequence<ClosedRange<Int>, Never>(sequence: 1...10)
		let e = expectation(description: "")
		var received = [Subscribers.Event<Int, Never>]()
		let c = sequence
			.receive(on: DispatchQueue.global())
			.receive(on: DispatchQueue.main)
			.sink(
				receiveCompletion: {
					received.append(.complete($0))
					e.fulfill()
				},
				receiveValue: { received.append(.value($0)) }
			)
		withExtendedLifetime(c) { wait(for: [e], timeout: 5.0) }
		XCTAssertNotEqual(received, (1...10).asCombineArray(completion: .finished))
	}

	func testReentrancy() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let subscriber = Subscribers.Sink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { v in
				received.append(.value(v))
				if received.count < 3 {
					subject.send(v + 1)
				}
			}
		)
		subject.subscribe(subscriber)
		
		subject.send(sequence: 1...1, completion: .finished)
		XCTAssertEqual(received, (1...3).asCombineArray(completion: .finished))
		
		subscriber.cancel()
	}
	
	func testSubjectOrder() {
		let sequenceLength = 100
		let subject = PassthroughSubject<Int, Never>()
		let semaphore = DispatchSemaphore(value: 0)
		
		let total = AtomicBox<Int>(0)
		var collision = false
		let c = subject
			.sink(receiveValue: { value in
				if total.isMutating {
					// Check to see if this closure is concurrently invoked
					collision = true
				}
				total.mutate { total in
					// Make sure we're in the handler for enough time to get a concurrent invocation
					Thread.sleep(forTimeInterval: 0.001)
					total += value
					if total == sequenceLength {
						semaphore.signal()
					}
				}
			})
		
		// Try to send from a hundred different threads at once
		for _ in 1...sequenceLength {
			DispatchQueue.global().async {
				subject.send(1)
			}
		}
		
		semaphore.wait()
		c.cancel()
		XCTAssertEqual(total.value, sequenceLength)
		XCTAssertFalse(collision)
	}
	
	#if false
	// NOTE: this test deadlocks
	func testDeadlock() {
		let subject = PassthroughSubject<Int, Never>()
		let semaphore = DispatchSemaphore(value: 0)
		
		let sequenceLength = 100
		var total = 0
		let t = mach_absolute_time()
		let c = subject
			.sink(receiveValue: { value in
				total += value
				if total < sequenceLength {
					DispatchQueue.main.sync { subject.send(1) }
				}
			})
		DispatchQueue.global().async { subject.send(1) }
		while total < sequenceLength {
			RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
		}
		c.cancel()
		
		XCTAssertEqual(total, sequenceLength)
	}
	#endif
}
