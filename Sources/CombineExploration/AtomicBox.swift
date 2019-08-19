//
//  AtomicBox.swift
//  CombineExploration
//
//  Created by Matt Gallagher on 16/7/19.
//  Copyright © 2019 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//

import Foundation

/// A mutex wrapper around contents.
/// Useful for threadsafe access to single values but less useful for compound values where different components might need to be updated at different times.
public final class AtomicBox<T> {
	@usableFromInline
	var mutex = os_unfair_lock()

	@usableFromInline
	var internalValue: T
	
	public init(_ t: T) {
		internalValue = t
	}
	
	@inlinable
	public var value: T {
		get {
			os_unfair_lock_lock(&mutex)
			defer { os_unfair_lock_unlock(&mutex) }
			return internalValue
		}
	}
	
	public var isMutating: Bool {
		if os_unfair_lock_trylock(&mutex) {
			os_unfair_lock_unlock(&mutex)
			return false
		}
		return true
	}
	
	@discardableResult @inlinable
	public func mutate<U>(_ f: (inout T) throws -> U) rethrows -> U {
		os_unfair_lock_lock(&mutex)
		defer { os_unfair_lock_unlock(&mutex) }
		return try f(&internalValue)
	}
}
