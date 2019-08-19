//
//  ProtocolTests.swift
//  CombineExplorationTests
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//

import XCTest
import Foundation
import Combine
import CombineExploration

class ProtocolTests: XCTestCase {
	func testSubjectSink() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let sink = Subscribers.Sink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		
		subject.subscribe(sink)
		subject.send(sequence: 1...3, completion: .finished)
		
		XCTAssertEqual(received, (1...3).asCombineArray(completion: .finished))
	}
	
	func testScanABC() {
		let subjectA = PassthroughSubject<Int, Never>()
		let scanB = subjectA.scan(10) { state, next in state + next }
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = Subscribers.Sink<Int, Never>(
			receiveCompletion: { receivedC.append(.complete($0)) },
			receiveValue: { receivedC.append(.value($0)) }
		)

		scanB.subscribe(sinkC)
		subjectA.send(sequence: 1...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
	}
	
	func testSequenceABCD() {
		let sequenceA = Publishers.Sequence<ClosedRange<Int>, Never>(sequence: 1...4)
		let scanB = Publishers.Scan(upstream: sequenceA, initialResult: 10) { state, next in state + next }
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
		scanB.subscribe(sinkD)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [11, 13, 16, 20].asCombineArray(completion: .finished))
	}
	
	func testOverlappingABCD() {
		var subjects = [PassthroughSubject<Int, Never>]()
		let deferred = Deferred { () -> PassthroughSubject<Int, Never> in
			let request = PassthroughSubject<Int, Never>()
			subjects.append(request)
			return request
		}
		let scanB = Publishers.Scan(upstream: deferred, initialResult: 10) { state, next in state + next }
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
		subjects[0].send(sequence: 1...2, completion: nil)
		scanB.subscribe(sinkD)
		subjects[0].send(sequence: 3...4, completion: .finished)
		subjects[1].send(sequence: 1...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [11, 13, 16, 20].asCombineArray(completion: .finished))
	}
	
	func testCustomPublishCustomSink() {
		let subject = CustomSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let sink = CustomSink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		subject.subscribe(sink)
		
		subject.send(sequence: 1...3, completion: .finished)
		
		XCTAssertEqual(received, (1...3).asCombineArray(completion: .finished))
	}

	func testCombinePublishCustomSink() {
		let subject = PassthroughSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let subscriber = CustomSink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		subject.subscribe(subscriber)
		
		subject.send(sequence: 1...3, completion: .finished)
		
		XCTAssertEqual(received, (1...3).asCombineArray(completion: .finished))
	}

	func testCustomPublishCombineSubscribe() {
		let subject = CustomSubject<Int, Never>()
		var received = [Subscribers.Event<Int, Never>]()
		let subscriber = Subscribers.Sink<Int, Never>(
			receiveCompletion: { received.append(.complete($0)) },
			receiveValue: { received.append(.value($0)) }
		)
		subject.subscribe(subscriber)
		
		subject.send(sequence: 1...3, completion: .finished)
		
		XCTAssertEqual(received, (1...3).asCombineArray(completion: .finished))
	}
	
	func testCustomABCD() {
		var subjects = [CustomSubject<Int, Never>]()
		let deferred = Deferred { () -> CustomSubject<Int, Never> in
			let request = CustomSubject<Int, Never>()
			subjects.append(request)
			return request
		}
		let scanB = CustomScan(upstream: deferred, initialResult: 10) { state, next in state + next }
		var receivedC = [Subscribers.Event<Int, Never>]()
		let sinkC = CustomSink<Int, Never>(
			receiveCompletion: { receivedC.append(.complete($0)) },
			receiveValue: { receivedC.append(.value($0)) }
		)
		var receivedD = [Subscribers.Event<Int, Never>]()
		let sinkD = CustomSink<Int, Never>(
			receiveCompletion: { receivedD.append(.complete($0)) },
			receiveValue: { receivedD.append(.value($0)) }
		)

		scanB.subscribe(sinkC)
		subjects[0].send(sequence: 1...2, completion: nil)
		scanB.subscribe(sinkD)
		subjects[0].send(sequence: 3...4, completion: .finished)
		subjects[1].send(sequence: 1...4, completion: .finished)
		
		XCTAssertEqual(receivedC, [11, 13, 16, 20].asCombineArray(completion: .finished))
		XCTAssertEqual(receivedD, [11, 13, 16, 20].asCombineArray(completion: .finished))
	}
}
