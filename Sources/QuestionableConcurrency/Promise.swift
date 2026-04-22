//
//  Promise.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-16.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

/// A _Promise_ to provide a deferred value that can be fulfilled at a later time.
///
/// A promise vends a ``future``, whose ``AsyncResult/value-5r346`` can be awaited in a separate ``/Concurrency/Task`` to suspend that task until the promise is ready to be fulfilled.
///
/// A promise is fulfilled by being resumed _exactly once_ using ``resume(with:)-(Result<Success,Failure>)``. A promise's ``future`` should be saved separately before resuming the promise.
///
/// Promises are validated at compile time to ensure they are resumed no more than once, and trap immediately at runtime once their owning scope concludes.
///
/// - Warning: A promise's ``Future`` must _not_ be awaited prior to being fulfilled, which will immediately deadlock.
public struct Promise<
    Success: Sendable,
    Failure: Error
>: ~Copyable, Sendable {
    
    /// The name of the promise for debugging purposes.
    public let name: String
    
    /// The internal continuation used to fulfill the promise.
    let continuation: DeferredContinuation<Success, Failure>
    
    /// The associated future that can be read to suspend and wait for the fulfilled value to be delivered.
    ///
    /// An associated future may be shared freely with other parts of a program to provide controls for enabling async pathways from a distance.
    public let future: Future<Success, Failure>
    
    /// Initialize a new promise whose value can be read later.
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is never resumed.
    ///   - successType: The success type for the promise.
    ///   - failureType: The success type for the promise.
    public init(
        name promiseName: String? = nil,
        of successType: Success.Type = Success.self,
        throws failureType: Failure.Type = Failure.self
    ) {
        let promiseName = promiseName ?? "QuestionableConcurrency.Promise<\(successType), \(failureType)>"
        name = promiseName
        continuation = DeferredContinuation(name: promiseName)
        future = continuation.future
    }
    
    /// A promise expires after its creating scope concludes, and will trap if it hasn't been resumed.
    deinit {
        /// If our continuation is still pending, the promise was never resumed, so trap at runtime.
        continuation.trapIfPending()
    }
    
    /// Fulfill a promise by resuming it with a result.
    /// - Parameter result: The result that should be returned when ``future``'s ``AsyncResult/value-5r346`` is awaited.
    public consuming func resume(with result: sending Result<Success, Failure>) {
        continuation.resume(with: result)
    }
}

extension Promise where Success == Void {
    /// Initialize a new promise whose value can be yielded later.
    /// - SeeAlso: ``Promise``
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is misused.
    ///   - successType: The success type for the promise.
    ///   - failureType: The failure type for the promise.
    public init(
        name promiseName: String? = nil,
        throws failureType: Failure.Type = Failure.self
    ) {
        self.init(name: promiseName, of: Void.self, throws: failureType)
    }
}

extension Promise where Success == Never {
    /// Initialize a new always-throwing promise whose value can be read later.
    /// - SeeAlso: ``Promise``
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is misused.
    ///   - successType: The success type for the promise.
    ///   - failureType: The failure type for the promise.
    public init(
        name promiseName: String? = nil,
        alwaysThrows failureType: Failure.Type = Failure.self
    ) {
        self.init(name: promiseName, of: Never.self, throws: failureType)
    }
}

extension Promise where Failure == Never {
    /// Initialize a new never-failing promise whose value can be read later.
    /// - SeeAlso: ``Promise``
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is misused.
    ///   - successType: The success type for the promise.
    ///   - failureType: The failure type for the promise.
    public init(
        name promiseName: String? = nil,
        of successType: Success.Type = Success.self
    ) {
        self.init(name: promiseName, of: successType, throws: Never.self)
    }
}

extension Promise where Success == Void, Failure == Never {
    /// Initialize a new never-failing promise whose value can be read later.
    /// - SeeAlso: ``Promise``
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is misused.
    ///   - successType: The success type for the promise.
    ///   - failureType: The failure type for the promise.
    public init(
        name promiseName: String? = nil
    ) {
        self.init(name: promiseName, of: Void.self, throws: Never.self)
    }
}

extension Promise where Failure == any Error {
    /// Initialize a new throwing promise whose value can be read later.
    /// - SeeAlso: ``Promise``
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is misused.
    ///   - successType: The success type for the promise.
    ///   - failureType: The failure type for the promise.
    public static func throwing(
        name promiseName: String? = nil,
        of successType: Success.Type = Success.self
    ) -> Self {
        self.init(name: promiseName, of: successType, throws: (any Error).self)
    }
}

extension Promise where Success == Void, Failure == any Error {
    /// Initialize a new throwing promise whose value can be yielded later.
    /// - SeeAlso: ``Promise``
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is misused.
    ///   - successType: The success type for the promise.
    ///   - failureType: The failure type for the promise.
    public static func throwing(
        name promiseName: String? = nil
    ) -> Self {
        self.init(name: promiseName, of: Void.self, throws: (any Error).self)
    }
}

extension Promise where Success == Never, Failure == any Error {
    /// Initialize a new always-throwing promise whose value can be yielded later.
    /// - SeeAlso: ``Promise``
    /// - Parameters:
    ///   - promiseName: A name to assign to the promise to track when it is misused.
    ///   - successType: The success type for the promise.
    ///   - failureType: The failure type for the promise.
    public static func alwaysThrowing(
        name promiseName: String? = nil
    ) -> Self {
        self.init(name: promiseName, of: Never.self, throws: (any Error).self)
    }
}

extension Promise {
    /// Fulfill a promise by resuming it with a successful value.
    /// - Parameter result: The value that should be returned when ``future``'s ``AsyncResult/value-5r346`` is awaited.
    public consuming func resume(returning value: sending Success) {
        resume(with: .success(value))
    }
    
    /// Fulfill a promise by resuming it with a failing error.
    /// - Parameter result: The error that should be thrown when ``future``'s ``AsyncResult/value-5r346`` is awaited.
    public consuming func resume(throwing error: Failure) {
        resume(with: .failure(error))
    }
    
    /// Fulfill a promise by resuming it with a result.
    /// - Parameter result: The result that should be returned when ``future``'s ``AsyncResult/result`` is awaited.
    public consuming func resume<LocalFailure>(with result: sending Result<Success, LocalFailure>) where Failure == any Error, LocalFailure: Error {
        resume(with: result.mapError { $0 as Failure })
    }
    
    /// Fulfill a promise by resuming it.
    /// - Parameter result: Un-suspend any tasks awaiting ``future``'s ``AsyncResult/value``.
    public consuming func resume() where Success == () {
        resume(with: .success(()))
    }
}
