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
/// Unlike ``/Concurrency/CheckedContinuation`` and ``/Concurrency/UnsafeContinuation``, ``DeferredContinuation`` can be initialized anywhere, and its ``future`` can be awaited at any time. Similarly to the standard library types, a continuation _must_ be resumed exactly once using ``resume(with:)``.
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
    nonisolated public let name: String
    
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
    /// - Parameter result: The result that should be returned when ``future`` is read.
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
    
    /// The future value associated with the continuation.
    ///
    /// If the continuation has been fulfilled, the value is immediately available without suspending.
    public nonisolated var future: Future<Success, Failure> {
        AsyncResult.cached { [self] () async throws(Failure) -> Success in
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

extension DeferredContinuation where Success == Void {
    /// Initialize a new deferred continuation whose value can be yielded later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public init(
        name continuationName: String? = nil,
        throws failureType: Failure.Type = Failure.self
    ) {
        self.init(name: continuationName, of: Void.self, throws: failureType)
    }
}

extension DeferredContinuation where Success == Never {
    /// Initialize a new always-throwing deferred continuation whose value can be read later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public init(
        name continuationName: String? = nil,
        alwaysThrows failureType: Failure.Type = Failure.self
    ) {
        self.init(name: continuationName, of: Never.self, throws: failureType)
    }
}

extension DeferredContinuation where Failure == Never {
    /// Initialize a new never-failing deferred continuation whose value can be read later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public init(
        name continuationName: String? = nil,
        of successType: Success.Type = Success.self
    ) {
        self.init(name: continuationName, of: successType, throws: Never.self)
    }
}

extension DeferredContinuation where Success == Void, Failure == Never {
    /// Initialize a new never-failing deferred continuation whose value can be read later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public init(
        name continuationName: String? = nil
    ) {
        self.init(name: continuationName, of: Void.self, throws: Never.self)
    }
}

extension DeferredContinuation where Failure == any Error {
    /// Initialize a new throwing deferred continuation whose value can be read later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public static func throwing(
        name continuationName: String? = nil,
        of successType: Success.Type = Success.self
    ) -> Self {
        self.init(name: continuationName, of: successType, throws: (any Error).self)
    }
}

extension DeferredContinuation where Success == Void, Failure == any Error {
    /// Initialize a new throwing deferred continuation whose value can be yielded later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public static func throwing(
        name continuationName: String? = nil
    ) -> Self {
        self.init(name: continuationName, of: Void.self, throws: (any Error).self)
    }
}

extension DeferredContinuation where Success == Never, Failure == any Error {
    /// Initialize a new always-throwing deferred continuation whose value can be yielded later.
    /// - SeeAlso: ``DeferredContinuation``
    /// - Parameters:
    ///   - continuationName: A name to assign to the continuation to track when it is misused.
    ///   - successType: The success type for the continuation.
    ///   - failureType: The failure type for the continuation.
    public static func alwaysThrowing(
        name continuationName: String? = nil
    ) -> Self {
        self.init(name: continuationName, of: Never.self, throws: (any Error).self)
    }
}
