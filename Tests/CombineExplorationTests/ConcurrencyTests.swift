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
	func testSinkCancellationPlusImmediateAsyncDelivery() {
		var received = [Subscribers.Event<Int, Never>]()
		let sequence = Just(1)
			.receive(on: DispatchQueue.main)
			.customSink(
				receiveCompletion: { c in received.append(.complete(c)) },
				receiveValue: { v in received.append(.value(v)) }
			)
		
		sequence.cancel()
		XCTAssertEqual(received, [].asEvents(completion: nil))
		
		RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.001))
		XCTAssertEqual(received, [].asEvents(completion: nil))
	}

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
		sink.increaseDemand(2)
		
		XCTAssertEqual(received, [1, 2, 4, 5].asEvents(completion: .finished))
	}

	func testDemandWithBuffer() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let sink = CustomDemandSink<Int, Never>(
			demand: 1,
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		subject.buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest).subscribe(sink)
		
		subject.send(sequence: 1...3, completion: nil)
		sink.increaseDemand(1)
		subject.send(sequence: 4...6, completion: .finished)
		sink.increaseDemand(1)
		
		XCTAssertEqual(received, [1, 3, 6].asEvents(completion: nil))
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
		XCTAssertNotEqual(received, (1...10).asEvents(completion: .finished))
	}

	func testReentrancy() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let subscriber = Subscribers.Sink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { v in
				if v < 3 {
					subject.send(v + 1)
				}
				received.append(.value(v))
			}
		)
		subject.subscribe(subscriber)
		
		subject.send(sequence: 1...1, completion: .finished)
		XCTAssertEqual(received, [3, 2, 1].asEvents(completion: .finished))
		
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
	
	func testReceiveWithLogging() {
		let subject = PassthroughSubject<Int, Never>()

		print("Start...")
		var received = [Subscribers.Event<Int, Never>]()
		let cancellable = subject
			.debug()
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: { received.append(.value($0)) })
		
		print("Phase 1...")
		subject.send(1)
		XCTAssertEqual(received, [].asEvents(completion: nil))
		
		print("Phase 2...")
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
		XCTAssertEqual(received, [].asEvents(completion: nil))
		
		print("Phase 3...")
		subject.send(2)
		XCTAssertEqual(received, [].asEvents(completion: nil))
		
		print("Phase 4...")
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
		XCTAssertEqual(received, [2].asEvents(completion: nil))
		
		cancellable.cancel()
	}
	
	func testReceiveOnImmediate() {
		let e = expectation(description: "")
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let c = subject
			.receive(on: ImmediateScheduler.shared)
			.sink(
				receiveCompletion: { 
					received.append(.complete($0))
					e.fulfill()
				},
				receiveValue: { received.append(.value($0)) }
			)
		
		subject.send(1)
		subject.send(completion: .finished)
		wait(for: [e], timeout: 5.0)

		XCTAssertEqual(received, [1].asEvents(completion: .finished))

		c.cancel()
	}

	func testReceiveOnFailure() {
		let queue = DispatchQueue(label: "test")
		let e = expectation(description: "")
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let c = subject
			.receive(on: queue)
			.sink(
				receiveCompletion: { 
					received.append(.complete($0))
					e.fulfill()
				},
				receiveValue: { received.append(.value($0)) }
			)
		
		subject.send(1)
		queue.async { subject.send(completion: .finished) }
		wait(for: [e], timeout: 5.0)

		XCTAssertEqual(received, [].asEvents(completion: .finished))
		
		c.cancel()
	}
	
	func testBufferedReceiveOn() {
		let subject = PassthroughSubject<Int, Never>()
		let e = expectation(description: "")
		var received = [Subscribers.Event<Int, Never>]()
		let c = subject
			.buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropNewest)
			.receive(on: DispatchQueue(label: "test"))
			.sink(
				receiveCompletion: {
					received.append(.complete($0))
					e.fulfill()
				},
				receiveValue: { received.append(.value($0)) }
			)
		
		subject.send(1)
		subject.send(completion: .finished)
		wait(for: [e], timeout: 5.0)

		XCTAssertEqual(received, [1].asEvents(completion: .finished))

		c.cancel()
	}
	
	#if false
	// NOTE: this test intentionally deadlocks
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
