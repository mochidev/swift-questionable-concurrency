//
//  DeferredContinuation.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-19.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

/// A continuation that can be used to suspend a task multiple times and be resumed exactly once after creation.
///
/// If a continuation is resumed more than once, it'll trap the second time ``resume(with:)`` is called. Similarly, if a continuation is never resumed, ``trapIfPending()`` can be used to check and trap on demand. This functionality is used internally by ``Promise`` to trap as soon as the owning scope concludes.
///
/// ## Comparison with Standard Types
///
/// Unlike ``/Concurrency/CheckedContinuation`` and ``/Concurrency/UnsafeContinuation``, ``DeferredContinuation`` can be initialized anywhere, and its ``value`` can be awaited at any time. Similarly to the standard library types, a continuation _must_ be resumed exactly once using ``resume(with:)``.
///
/// In `DEBUG` builds, a ``/Concurrency/CheckedContinuation`` will be used internally to suspend the current task when a value is read. In `RELEASE` builds, a ``/Concurrency/UnsafeContinuation`` will be used instead.
///
/// - SeeAlso: Use ``Promise`` instead for a safer interface for working with deferred values.
public actor DeferredContinuation<
    Success: Sendable,
    Failure: Error
>: Sendable {
    /// In `DEBUG` builds, use a ``Concurrency/CheckedContinuation`` to suspend the current task when a value is read. In `RELEASE` builds, a ``Concurrency/UnsafeContinuation`` will be used instead.
    #if DEBUG
    typealias Continuation = CheckedContinuation<Success, any Error>
    #else
    typealias Continuation = UnsafeContinuation<Success, any Error>
    #endif
    
    /// Internal state for tracking if the continuation is still pending, or if its been fulfilled.
    enum State: Sendable {
        /// A continuation that is still pending, with space to collect all suspensions.
        case pending([Continuation])
        /// A continuation that has been fulfilled, with space for the underlying result.
        case fulfilled(Result<Success, Failure>)
    }
    
    /// The name of the continuation for debugging purposes.
    public let name: String
    
    /// The internal lock for maintaining exclusive access to changes to ``state``.
    let lock: UnfairLock = UnfairLock()
    
    /// The internal state for tracking where the continuation stands.
    nonisolated(unsafe) var state: State = .pending([])
    
    /// Initialize a new deferred continuation whose value can be read later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public init(
        name continuationName: String? = nil,
        of successType: Success.Type = Success.self,
        throws failureType: Failure.Type = Failure.self
    ) {
        self.name = continuationName ?? "QuestionableConcurrency.DeferredContinuation<\(successType), \(failureType)>"
    }
    
    /// Check to see if a continuation is still pending, and immediately trap at runtime if it is.
    /// - SeeAlso: The ``name`` assigned to the continuation.
    public nonisolated func trapIfPending() {
        lock.withLock {
            switch state {
            case .pending:
                /// If we still have a continuation, then trap at runtime since the promise was forgotten.
                fatalError("\(name) was dropped without being resumed.")
            case .fulfilled: break
            }
        }
    }
    
    /// Resume a continuation.
    ///
    /// - Warning: A continuation must be resumed _exactly_ once. If a continuation is resumed a second time, it'll immediately trap at runtime.
    /// - SeeAlso: The ``name`` assigned to the continuation.
    /// - Parameter result: The result that should be returned when ``value`` is read.
    public nonisolated func resume(with result: sending Result<Success, Failure>) {
        let continuations = lock.withLock {
            switch state {
            case .pending(let continuations):
                state = .fulfilled(result)
                return continuations
            case .fulfilled:
                fatalError("\(name) was resumed more than once.")
            }
        }
        for continuation in continuations {
            continuation.resume(with: result)
        }
    }
    
    /// The value that the continuation is resumed with, or a thrown error if it was resumed with a failure.
    ///
    /// If the continuation has been fulfilled, the value is immediately available without suspending.
    public nonisolated(nonsending) var value: Success {
        get async throws(Failure) {
            /// Lock around reading and updating state across the continuation boundary.
            lock.unsafeLock()
            switch state {
            case .pending(let continuations):
                do {
                    #if DEBUG
                    return try await withCheckedThrowingContinuation { continuation in
                        state = .pending(continuations + [continuation])
                        lock.unsafeUnlock()
                    }
                    #else
                    return try await withUnsafeThrowingContinuation { continuation in
                        state = .pending(continuations + [continuation])
                        lock.unsafeUnlock()
                    }
                    #endif
                } catch {
                    throw error as! Failure
                }
            case .fulfilled(let success):
                lock.unsafeUnlock()
                return try success.get()
            }
        }
    }
}
