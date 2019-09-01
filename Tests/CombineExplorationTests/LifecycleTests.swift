//
//  LifecycleTests.swift
//  CombineExplorationTests
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
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
		let sinkC = scanB.sink(event: { e in receivedC.append(e) })
		subjectA.send(sequence: 1...2, completion: nil)
		
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = scanB.sink(event: { e in receivedD.append(e) })
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
		XCTAssertEqual(receivedD, [13, 17].asEvents(completion: .finished))
		
		sinkC.cancel()
		sinkD.cancel()
	}

	func testMulticastABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let multicastB = subjectA
			.scan(10) { state, next in state + next }
			.multicast { PassthroughSubject() }
		let cancelB = multicastB.connect()
		
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = multicastB.sink(event: { e in receivedC.append(e) })
		subjectA.send(sequence: 1...2, completion: nil)
		
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = multicastB.sink(event: { e in receivedD.append(e) })
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
		XCTAssertEqual(receivedD, [16, 20].asEvents(completion: .finished))
		
		sinkC.cancel()
		sinkD.cancel()
		cancelB.cancel()
	}
	
	func testBufferedABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let multicastB = subjectA
			.scan(10) { state, next in state + next }
			.buffer(size: Int.max, prefetch: .keepFull, whenFull: .dropNewest)
			.multicast { PassthroughSubject() }
		let cancelB = multicastB.connect()
		
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = multicastB.sink(event: { e in receivedC.append(e) })
		subjectA.send(sequence: 1...2, completion: nil)
		
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = multicastB.sink(event: { e in receivedD.append(e) })
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
		XCTAssertEqual(receivedD, [16, 20].asEvents(completion: .finished))
		
		sinkC.cancel()
		sinkD.cancel()
		cancelB.cancel()
	}
	
	func testMulticastLatestABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let multicastB = subjectA
			.scan(10) { state, next in state + next }
			.multicast { CurrentValueSubject(0) }
		let cancelB = multicastB.connect()
		
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = multicastB.sink(event: { e in receivedC.append(e) })
		subjectA.send(sequence: 1...2, completion: nil)
		
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = multicastB.sink(event: { e in receivedD.append(e) })
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [0, 11, 13, 16, 20].asEvents(completion: .finished))
		XCTAssertEqual(receivedD, [13, 16, 20].asEvents(completion: .finished))
		
		sinkC.cancel()
		sinkD.cancel()
		cancelB.cancel()
	}
	
	func testBufferMulticastABCD() {
		let subjectA = PassthroughSubject<Int, Never>()
		let multicastB = subjectA
			.scan(10) { state, next in state + next }
			.multicast { BufferSubject(limit: Int.max) }
		let cancelB = multicastB.connect()
		
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = multicastB.sink(event: { e in receivedC.append(e) })
		subjectA.send(sequence: 1...2, completion: nil)
		
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = multicastB.sink(event: { e in receivedD.append(e) })
		subjectA.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
		XCTAssertEqual(receivedD, [11, 13, 16, 20].asEvents(completion: .finished))
		
		sinkC.cancel()
		sinkD.cancel()
		cancelB.cancel()
	}

	func testMultipleSubscribe() {
		let subject1 = PassthroughSubject<Int, Never>()
		let subject2 = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let sink = Subscribers.Sink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		subject1.subscribe(sink)
		subject2.subscribe(sink)

		subject1.send(sequence: 1...2, completion: .finished)
		subject2.send(sequence: 3...4, completion: .finished)
	
		XCTAssertEqual(received, (1...2).asEvents(completion: .finished))
	}

	func testMultiSubjectSubscribe() {
		let subject1 = PassthroughSubject<Int, Never>()
		let subject2 = PassthroughSubject<Int, Never>()
		let multiInputSubject = PassthroughSubject<Int, Never>()
		let cancellable1 = subject1.subscribe(multiInputSubject)
		let cancellable2 = subject2.subscribe(multiInputSubject)
		var received = [Subscribers.Event<Int, Never>]()
		let multiInputCancellable = multiInputSubject.sink(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		
		subject1.send(sequence: 1...2, completion: nil)
		subject2.send(sequence: 3...4, completion: .finished)
		
		XCTAssertEqual(received, [1, 2, 3, 4].asEvents(completion: .finished))

		cancellable1.cancel()
		cancellable2.cancel()
		multiInputCancellable.cancel()
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
		
		XCTAssertEqual(received, [1, 2, 3, 4].asEvents(completion: nil))

		cancellable.cancel()
	}
	
	func testAnyCancellable() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()

		weak var weakCancellable: AnyCancellable?
		do {
			let anyCancellable = subject
				.sink(event: { e in received.append(e) } )
			weakCancellable = anyCancellable
			subject.send(1)
		}
		XCTAssertNil(weakCancellable)
		
		subject.send(2)
		XCTAssertEqual(received, [1].asEvents(completion: nil))
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
		XCTAssertEqual(received, [1, 2].asEvents(completion: nil))
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
		}
		XCTAssertNotNil(weakSubject)
		XCTAssertNotNil(weakSink)

		weakSubject?.send(1)
		weakSubject?.send(completion: .finished)

		XCTAssertNil(weakSubject)
		XCTAssertNil(weakSink)
		XCTAssertEqual(received, [1].asEvents(completion: .finished))
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
		
		// At this point, the first subscription to sink is finished
		XCTAssertNil(weakSubject)
		XCTAssertEqual(received, [1].asEvents(completion: .finished))
		
		// Try to start a new one
		let subject2 = PassthroughSubject<Int, Never>()
		subject2.subscribe(sink)
		subject2.send(2)
		
		#if false
			// Prior to macOS 10.15 beta 6...
			XCTAssertEqual(received,
				[1].asEvents(completion: .finished) + [2].asEvents(completion: nil)
			)
		#else
			// In macOS 10.15 beta 6...
			XCTAssertEqual(received, [1].asEvents(completion: .finished)
			)
		#endif
	}
	
	func testSinkCancellationPlusAsyncDelivery() {
		var received = [Subscribers.Event<Int, Never>]()
		let sink = Just(1)
			.receive(on: DispatchQueue.main)
			.sink(event: { e in received.append(e) })

		sink.cancel()
		XCTAssertEqual(received, [].asEvents(completion: nil))

		RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.001))
		XCTAssertEqual(received, [1].asEvents(completion: .finished))
	}
}
