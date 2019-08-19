//
//  LifecycleTests.swift
//  CombineExplorationTests
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//

import XCTest
import Foundation
import Combine
import CombineExploration

class LifecycleTests: XCTestCase {
	func testSharedSubjectABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let scanB = subjectA.scan(10) { state, next in state + next }
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedC.append(.complete($0)) },
			receiveValue: { receivedC.append(.value($0)) }
		)
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedD.append(.complete($0)) },
			receiveValue: { receivedD.append(.value($0)) }
		)

		scanB.subscribe(sinkC)
		subjectA.send(sequence: 1...2, completion: nil)
		scanB.subscribe(sinkD)
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [13, 17].asCombineArray(completion: .finished))
		
		sinkC.cancel()
		sinkD.cancel()
	}

	func testMulticastABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let scanB = Publishers.Scan(upstream: subjectA, initialResult: 10) { state, next in state + next }
		let multicastB = Publishers.Multicast(upstream: scanB) { PassthroughSubject() }
		let cancellableB = multicastB.connect()
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedC.append(.complete($0)) },
			receiveValue: { receivedC.append(.value($0)) }
		)
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedD.append(.complete($0)) },
			receiveValue: { receivedD.append(.value($0)) }
		)

		multicastB.subscribe(sinkC)
		subjectA.send(sequence: 1...2, completion: nil)
		multicastB.subscribe(sinkD)
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [16, 20].asCombineArray(completion: .finished))
		
		cancellableB.cancel()
		sinkC.cancel()
		sinkD.cancel()
	}
	
	func testBufferedABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let scanB = Publishers.Scan(upstream: subjectA, initialResult: 10) { state, next in state + next }
		let bufferB = Publishers.Buffer(upstream: scanB, size: Int.max, prefetch: .keepFull, whenFull: .dropNewest)
		let multicastB = Publishers.Multicast(upstream: bufferB) { PassthroughSubject() }
		let cancellableB = multicastB.connect()
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedC.append(.complete($0)) },
			receiveValue: { receivedC.append(.value($0)) }
		)
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedD.append(.complete($0)) },
			receiveValue: { receivedD.append(.value($0)) }
		)

		multicastB.subscribe(sinkC)
		subjectA.send(sequence: 1...2, completion: nil)
		multicastB.subscribe(sinkD)
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [16, 20].asCombineArray(completion: .finished))
		
		cancellableB.cancel()
		sinkC.cancel()
		sinkD.cancel()
	}
	
	func testMulticastLatestABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let scanB = Publishers.Scan(upstream: subjectA, initialResult: 10) { state, next in state + next }
		let multicastB = Publishers.Multicast(upstream: scanB) { CurrentValueSubject<Int, Never>(0) }
		let cancellableB = multicastB.connect()
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedC.append(.complete($0)) },
			receiveValue: { receivedC.append(.value($0)) }
		)
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedD.append(.complete($0)) },
			receiveValue: { receivedD.append(.value($0)) }
		)

		multicastB.subscribe(sinkC)
		subjectA.send(sequence: 1...2, completion: nil)
		multicastB.subscribe(sinkD)
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [0, 11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [13, 16, 20].asCombineArray(completion: .finished))
		
		cancellableB.cancel()
		sinkC.cancel()
		sinkD.cancel()
	}
	
	func testBufferMulticastABCD() {
		var subjects = [PassthroughSubject<Int, Never>]()
		let deferredA = Deferred { () -> PassthroughSubject<Int, Never> in
			let request = PassthroughSubject<Int, Never>()
			subjects.append(request)
			return request
		}
		let scanB = Publishers.Scan(upstream: deferredA, initialResult: 10) { state, next in state + next }
		let multicastB = Publishers.Multicast(upstream: scanB) {
			BufferSubject(limit: Int.max)
		}
		let cancellableB = multicastB.connect()
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedC.append(.complete($0)) },
			receiveValue: { receivedC.append(.value($0)) }
		)
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedD.append(.complete($0)) },
			receiveValue: { receivedD.append(.value($0)) }
		)

		multicastB.subscribe(sinkC)
		subjects[0].send(sequence: 1...2, completion: nil)
		multicastB.subscribe(sinkD)
		subjects[0].send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssert(subjects.count == 1)
		
		cancellableB.cancel()
		sinkC.cancel()
		sinkD.cancel()
	}

	func testMultipleSubscribe() {
		let subject1 = PassthroughSubject<Int, Never>()
		let subject2 = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let sink = CustomSink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		subject1.subscribe(sink)
		subject2.subscribe(sink)

		subject1.send(sequence: 1...2, completion: .finished)
		subject2.send(sequence: 3...4, completion: .finished)
	
		XCTAssertEqual(received, (1...2).asCombineArray(completion: .finished) + [.complete(.finished)])
	}

	func testMultiSubjectSubscribe() {
		let subject1 = PassthroughSubject<Int, Never>()
		let subject2 = PassthroughSubject<Int, Never>()
		let subject3 = PassthroughSubject<Int, Never>()
		let cancellable1 = subject1.subscribe(subject3)
		let cancellable2 = subject2.subscribe(subject3)
		var received = [Subscribers.Event<Int, Never>]()
		let cancellable3 = subject3.sink(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		
		subject1.send(sequence: 1...2, completion: nil)
		subject2.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(received, [1, 2, 3, 4].asCombineArray(completion: .finished))

		cancellable1.cancel()
		cancellable2.cancel()
		cancellable3.cancel()
	}

	func testMergeSink() {
		let subject1 = PassthroughSubject<Int, Never>()
		let subject2 = PassthroughSubject<Int, Never>()
		let input = MergeInput<Int>()
		subject1.merge(into: input)
		subject2.merge(into: input)
		var received = [Subscribers.Event<Int, Never>]()
		let cancellable = input.sink(receiveValue: { received.append(.value($0)) })

		subject1.send(sequence: 1...2, completion: .finished)
		subject2.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(received, [1, 2, 3, 4].asCombineArray(completion: nil))

		cancellable.cancel()
	}
	
	func testReceiveOn() {
		let subject = PassthroughSubject<Int, Never>()

		print("Start...")
		var received = [Subscribers.Event<Int, Never>]()
		let cancellable = subject
			.debug()
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: { received.append(.value($0)) })
		
		print("Phase 1...")
		subject.send(1)
		XCTAssertEqual(received, [].asCombineArray(completion: nil))
		
		print("Phase 2...")
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
		XCTAssertEqual(received, [].asCombineArray(completion: nil))
		
		print("Phase 3...")
		subject.send(2)
		XCTAssertEqual(received, [].asCombineArray(completion: nil))
		
		print("Phase 4...")
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
		XCTAssertEqual(received, [2].asCombineArray(completion: nil))
		
		cancellable.cancel()
	}
	
	func testReceiveOnSuccess() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let c = subject
			.sink(
				receiveCompletion: { received.append(.complete($0)) },
				receiveValue: { received.append(.value($0)) }
			)
		
		subject.send(1)
		subject.send(completion: .finished)

		XCTAssertEqual(received, [1].asCombineArray(completion: .finished))

		c.cancel()
	}

	func testReceiveOnFailure() {
		let subject = PassthroughSubject<Int, Never>()
		let queue = DispatchQueue(label: "test")
		let e = expectation(description: "")
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

		XCTAssertEqual(received, [].asCombineArray(completion: .finished))
		
		c.cancel()
	}
	
	func testImmediateReceiveOn() {
		let subject = PassthroughSubject<Int, Never>()
		let e = expectation(description: "")
		var received = [Subscribers.Event<Int, Never>]()
		let c = subject
			.subscribeImmediateReceive(on: DispatchQueue(label: "test"))
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

		XCTAssertEqual(received, [1].asCombineArray(completion: .finished))

		c.cancel()
	}
	
	func testAnyCancellable() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()

		weak var weakCancellable: AnyCancellable?
		do {
			let anyCancellable: AnyCancellable = subject
				.sink(
					receiveCompletion: { received.append(.complete($0)) },
					receiveValue: { received.append(.value($0)) }
				)
			weakCancellable = anyCancellable
			
			subject.send(1)
		}
		XCTAssertNil(weakCancellable)
		
		subject.send(2)
		XCTAssertEqual(received, [1].asCombineArray(completion: nil))
	}
	
	func testSinkCancellation() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		
		weak var weakSink: Subscribers.Sink<Int, Never>?
		do {
			let sink = Subscribers.Sink<Int, Never>(
				receiveCompletion: { received.append(.complete($0)) },
				receiveValue: { received.append(.value($0)) }
			)
			weakSink = sink
			subject.subscribe(sink)
			
			subject.send(1)
		}
		XCTAssertNotNil(weakSink)
		
		subject.send(2)
		weakSink?.cancel()
		subject.send(3)
		XCTAssertEqual(received, [1, 2].asCombineArray(completion: nil))
	}
	
	func testOwnership() {
		var received = [Subscribers.Event<Int, Never>]()

		weak var weakSubject: PassthroughSubject<Int, Never>?
		weak var weakSink: Subscribers.Sink<Int, Never>?
		do {
			let subject = PassthroughSubject<Int, Never>()
			weakSubject = subject
			let sink = Subscribers.Sink<Int, Never>(
				receiveCompletion: { received.append(.complete($0)) },
				receiveValue: { received.append(.value($0)) }
			)
			weakSink = sink
			
			subject.subscribe(sink)
			subject.send(1)
		}
		XCTAssertNotNil(weakSubject)
		XCTAssertNotNil(weakSink)

		weakSubject?.send(completion: .finished)

		XCTAssertNil(weakSubject)
		XCTAssertNil(weakSink)
		XCTAssertEqual(received, [1].asCombineArray(completion: .finished))
	}

	func testSinkReactivation() {
		var received = [Subscribers.Event<Int, Never>]()
		let sink = Subscribers.Sink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		
		weak var weakSubject: PassthroughSubject<Int, Never>?
		do {
			let subject = PassthroughSubject<Int, Never>()
			weakSubject = subject
			subject.subscribe(sink)
			
			subject.send(1)
		}
		XCTAssertNotNil(weakSubject)
		
		weakSubject?.send(completion: .finished)
		
		XCTAssertNil(weakSubject)
		XCTAssertEqual(received, [1].asCombineArray(completion: .finished))
		
		let subject2 = PassthroughSubject<Int, Never>()
		subject2.subscribe(sink)
		subject2.send(2)
		
		XCTAssertEqual(received,
			[1].asCombineArray(completion: .finished) + [2].asCombineArray(completion: nil)
		)
	}
}
