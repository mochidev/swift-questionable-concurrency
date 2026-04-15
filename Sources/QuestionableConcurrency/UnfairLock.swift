//
//  UnfairLock.swift
//  QuestionableConcurrency
//
//  Created by Dimitri Bouniol on 2026-04-15.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Bionic)
import Bionic
#elseif canImport(wasi_pthread)
import wasi_pthread
#elseif canImport(WASILibc)
/// This variation of Web Assembly is supported, but is completely single threaded, so no implementation import is needed.
#elseif canImport(WinSDK)
import WinSDK
#else
#error("Unsupported platform")
#endif

/// An Unfair Lock that provides isolated access while locked.
///
/// - SeeAlso: Non-copyable lock variation inspired from [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms/blob/2971dd5d9f6e0515664b01044826bcea16e59fac/Sources/AsyncAlgorithms/Locking.swift#L50)
public struct UnfairLock: ~Copyable, Sendable {
    #if canImport(Darwin)
    /// Darwin platform lock.
    struct PlatformLock: ~Copyable, @unchecked Sendable {
        let lockPointer: UnsafeMutablePointer<os_unfair_lock>
        
        init() {
            lockPointer = .allocate(capacity: 1)
            lockPointer.initialize(to: os_unfair_lock())
        }
        
        deinit {
            lockPointer.deinitialize(count: 1)
            lockPointer.deallocate()
        }
        
        func unsafeLock() { os_unfair_lock_lock(lockPointer) }
        func unsafeUnlock() { os_unfair_lock_unlock(lockPointer) }
    }
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic) || canImport(wasi_pthread)
    /// POSIX platform lock.
    struct PlatformLock: ~Copyable, @unchecked Sendable {
        #if os(FreeBSD) || os(OpenBSD)
        let lockPointer: UnsafeMutablePointer<pthread_mutex_t?>
        #else
        let lockPointer: UnsafeMutablePointer<pthread_mutex_t>
        #endif
        
        init() {
            lockPointer = .allocate(capacity: 1)
            let result = pthread_mutex_init(lockPointer, nil)
            precondition(result == 0, "pthread_mutex_init failed")
        }
        
        deinit {
            let result = pthread_mutex_destroy(lockPointer)
            precondition(result == 0, "pthread_mutex_destroy failed")
            lockPointer.deinitialize(count: 1)
            lockPointer.deallocate()
        }
        
        func unsafeLock() { pthread_mutex_lock(lockPointer) }
        func unsafeUnlock() {
            let result = pthread_mutex_unlock(lockPointer)
            precondition(result == 0, "pthread_mutex_unlock failed")
        }
    }
    #elseif canImport(WASILibc)
    /// This variation of Web Assembly is supported, but is completely single threaded, so no implementation is needed.
    struct PlatformLock: ~Copyable, @unchecked Sendable {
        func unsafeLock() {}
        func unsafeUnlock() {}
    }
    #elseif canImport(WinSDK)
    /// Windows platform lock.
    struct PlatformLock: ~Copyable, @unchecked Sendable {
        let lockPointer: UnsafeMutablePointer<SRWLOCK>
        
        init() {
            lockPointer = .allocate(capacity: 1)
            InitializeSRWLock(lockPointer)
        }
        
        deinit {
            lockPointer.deinitialize(count: 1)
            lockPointer.deallocate()
        }
        
        func unsafeLock() { AcquireSRWLockExclusive(lockPointer) }
        func unsafeUnlock() { ReleaseSRWLockExclusive(lockPointer) }
    }
    #else
    #error("Unsupported UnfairLock platform.")
    #endif
    
    let internalLock: PlatformLock
    
    public init() { internalLock = PlatformLock() }
    
    /// Acquire an unsafe lock.
    ///
    /// ``unsafeUnlock()`` _must_ be called or the next use of the lock will deadlock.
    public func unsafeLock() { internalLock.unsafeLock() }
    
    /// Relinquish an unsafe lock.
    ///
    /// A lock must only be relinguished when ``unsafeLock()`` is called, or code will fault depending on the platform it runs on.
    public func unsafeUnlock() { internalLock.unsafeUnlock() }
    
    /// Acquire a lock for the duration of the given block.
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        unsafeLock()
        defer { unsafeUnlock() }
        return try body()
    }
}
