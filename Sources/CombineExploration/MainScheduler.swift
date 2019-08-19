//
//  File.swift
//  
//
//  Created by Matt Gallagher on 19/8/19.
//

import Combine
import Foundation

class MainScheduler: Scheduler {
	var now: DispatchQueue.SchedulerTimeType {
		return DispatchQueue.main.now
	}
	
	var minimumTolerance: DispatchQueue.SchedulerTimeType.Stride {
		return DispatchQueue.main.minimumTolerance
	}
	
	func schedule(options: DispatchQueue.SchedulerOptions?, _ action: @escaping () -> Void) {
		if Thread.current.isMainThread {
			action()
		} else {
			DispatchQueue.main.schedule(options: options, action)
		}
	}

	func schedule(after date: DispatchQueue.SchedulerTimeType, tolerance: DispatchQueue.SchedulerTimeType.Stride, options: DispatchQueue.SchedulerOptions?, _ action: @escaping () -> Void) {
		DispatchQueue.main.schedule(after: date, tolerance: tolerance, options: options, action)
	}

	func schedule(after date: DispatchQueue.SchedulerTimeType, interval: DispatchQueue.SchedulerTimeType.Stride, tolerance: DispatchQueue.SchedulerTimeType.Stride, options: DispatchQueue.SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
		DispatchQueue.main.schedule(after: date, interval: interval, tolerance: tolerance, options: options, action)
	}
}
