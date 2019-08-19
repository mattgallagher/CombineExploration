//
//  PerformanceTests.swift
//  CombineExplorationTests
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher. All rights reserved.
//

import XCTest
import Foundation
import Combine
import RxSwift
import CwlSignal

class PerformanceTests: XCTestCase {
	func testCombineSubjectSendPerformance() {
		let sequenceLength = 1_000_000
		let subject = PassthroughSubject<Int, Never>()
		
		var total = 0
		let t = mach_absolute_time()
		let c = subject.sink { value in
			total += value
		}
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				subject.send(i)
			}
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("**  Combine  ** send elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testRxSwiftSubjectSendPerformance() {
		let sequenceLength = 1_000_000
		let subject = PublishSubject<Int>()
		
		var total = 0
		let t = mach_absolute_time()
		let c = subject.subscribe(onNext: { value in
			total += value
		})
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				subject.onNext(i)
			}
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("%%  RxSwift  %% send elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testSignalSendPerformance() {
		let sequenceLength = 1_000_000
		let (input, signal) = Signal<Int>.create()
		
		var total = 0
		let t = mach_absolute_time()
		let c = signal.subscribe { result in
			total += result.value ?? 0
		}
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				input.send(result: .success(i))
			}
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("$$ CwlSignal $$ send elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testCombineSequenceDeliveryPerformance() {
		let sequenceLength = 1_000_000
		let sequence = Publishers.Sequence<ClosedRange<Int>, Never>(sequence: 1...sequenceLength)
		
		var total = 0
		let t = mach_absolute_time()
		_ = sequence.sink { value in
			total += value
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("**  Combine  ** sequence elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testRxSwiftSequenceDeliveryPerformance() {
		let sequenceLength = 1_000_000
		let sequence = Observable.from(1...sequenceLength)
		
		var total = 0
		let t = mach_absolute_time()
		_ = sequence.subscribe(onNext:{ value in
			total += value
		})
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("%%  RxSwift  %% sequence elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testSignalSequenceDeliveryPerformance() {
		let sequenceLength = 1_000_000
		let sequence = Signal.from(1...sequenceLength)
		
		var total = 0
		let t = mach_absolute_time()
		_ = sequence.subscribe { result in
			total += result.value ?? 0
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("$$ CwlSignal $$ sequence elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testCombineAsyncPerformance() {
		let sequenceLength = 1_000_000
		let subject = PassthroughSubject<Int, Never>()
		let semaphore = DispatchSemaphore(value: 0)
		
		var total = 0
		let t = mach_absolute_time()
		let c = subject
			.subscribeImmediateReceive(on: DispatchQueue(label: "test"))
			.sink(receiveCompletion: { _ in semaphore.signal() }, receiveValue: { total += $0 })
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				subject.send(i)
			}
			subject.send(completion: .finished)
			semaphore.wait()
		}
		
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("**  Combine  ** async elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testRxSwiftAsyncMapPerformance() {
		let sequenceLength = 1_000_000
		let subject = PublishSubject<Int>()
		let semaphore = DispatchSemaphore(value: 0)
		
		var total = 0
		let t = mach_absolute_time()
		let c = subject
			.observeOn(SerialDispatchQueueScheduler(internalSerialQueueName: "test"))
			.subscribe(onNext: { total += $0 }, onCompleted: { semaphore.signal() })
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				subject.onNext(i)
			}
			subject.on(.completed)
			semaphore.wait()
		}
		
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("%%  RxSwift  %% async elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testSignalAsyncMapPerformance() {
		let sequenceLength = 1_000_000
		let (input, signal) = Signal<Int>.create()
		
		var total = 0
		let t = mach_absolute_time()
		
		let semaphore = DispatchSemaphore(value: 0)
		let cancellable = signal
			.subscribe(context: .global) { result in
				switch result {
				case .success: total += result.value ?? 0
				case .failure: semaphore.signal()
				}
			}
		withExtendedLifetime(cancellable) {
			for i in 1...sequenceLength {
				input.send(result: .success(i))
			}
			input.complete()
			semaphore.wait()
		}
		
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("$$ CwlSignal $$ async elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testCombineDeepMapPerformance() {
		let sequenceLength = 1_000_000
		let subject = PassthroughSubject<Int, Never>()
		
		var total = 0
		let t = mach_absolute_time()
		let c = subject
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.sink { value in
				total += value
			}
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				subject.send(i)
			}
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("**  Combine  ** deep map elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testRxSwiftDeepMapPerformance() {
		let sequenceLength = 1_000_000
		let subject = PublishSubject<Int>()
		
		var total = 0
		let t = mach_absolute_time()
		let c = subject
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.subscribe(onNext: { value in
				total += value
			})
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				subject.onNext(i)
			}
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("%%  RxSwift  %% deep map elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
	
	func testSignalDeepMapPerformance() {
		let sequenceLength = 1_000_000
		let (input, signal) = Signal<Int>.create()
		
		var total = 0
		let t = mach_absolute_time()
		let c = signal
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.map { $0 }
			.subscribe { result in
				total += result.value ?? 0
			}
		withExtendedLifetime(c) {
			for i in 1...sequenceLength {
				input.send(result: .success(i))
			}
		}
		let elapsed = 1e-9 * Double(mach_absolute_time() - t)
		XCTAssertEqual(total, sequenceLength * (sequenceLength + 1) / 2)
		print("$$ CwlSignal $$ deep map elapsed is \(elapsed) seconds. Rate is \(Double(sequenceLength) / elapsed) per second.")
	}
}
