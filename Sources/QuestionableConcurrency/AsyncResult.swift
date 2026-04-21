//
//  AsyncResult.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-16.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

/// An asynchronous value or result that is fulfilled by the closure passed when initialized.
///
/// ### Typed Throws
///
/// To take advantage of typed throws, you must annotate your closure accordingly, otherwise `any Error` will be used:
///
/// ```swift
/// let implicitResult = AsyncResult {
///     throw TestError()
/// }
/// implicitResult is AsyncResult<(), any Error> // true
/// ```
/// ```swift
/// let explicitResult = AsyncResult { () throws(TestError) -> Never in
///     throw TestError()
/// }
/// explicitResult is AsyncResult<Never, TestError> // true
/// ```
public struct AsyncResult<
    Success: Sendable,
    Failure: Error
>: Sendable {
    /// The internal producer that vends the value as soon as it is unsuspended by its associated promise.
    let valueProducer: nonisolated(nonsending) @Sendable () async throws(Failure) -> Success
    
    /// Initialize an asynchronous value or result with the returned value or thrown error of a closure.
    ///
    /// - Important: If a task reading a ``value-5r346`` is cancelled, cancellation will propagate into the `body` block provided here for that read operation.
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter body: The asynchronous closure that either returns a successful value, or throws an error that will be captured.
    public init(catching body: nonisolated(nonsending) @Sendable @escaping () async throws(Failure) -> Success) {
        self.valueProducer = body
    }
}

extension AsyncResult {
    /// Initialize an asynchronous value or result with the returned result of a closure.
    ///
    /// - Important: If a task reading a ``value-5r346`` is cancelled, cancellation will propagate into the `resultProducer` block provided here for that read operation.
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter resultProducer: The closure that asynchronously returns a result.
    public init(async resultProducer: nonisolated(nonsending) @Sendable @escaping () async -> Result<Success, Failure>) {
        self.init { () async throws(Failure) -> Success in
            try await resultProducer().get()
        }
    }
    
    /// Initialize an asynchronous value or result with a synchronous ``/Swift/Result``.
    ///
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter result: The result to wrap.
    public init(_ result: Result<Success, Failure>) {
        self.init { () throws(Failure) -> Success in
            try result.get()
        }
    }
    
    /// A success, storing a `Success` value.
    /// - SeeAlso: ``AsyncResult``
    public static func success(_ value: Success) -> Self {
        AsyncResult(.success(value))
    }
    
    /// A failure, storing a `Failure` value.
    /// - SeeAlso: ``AsyncResult``
    public static func failure(_ error: Failure) -> Self {
        AsyncResult(.failure(error))
    }
}

extension AsyncResult where Failure == Never {
    /// A success, storing a `Success` value.
    /// - SeeAlso: ``AsyncResult``
    public static func success(_ value: Success) -> Self {
        AsyncResult(.success(value))
    }
}

extension AsyncResult where Success == Never {
    /// A failure, storing a `Failure` value.
    /// - SeeAlso: ``AsyncResult`` 
    public static func failure(_ error: Failure) -> Self {
        AsyncResult(.failure(error))
    }
}

extension AsyncResult {
    /// Initialize an asynchronous value or result with the returned value or thrown error of a closure, and immediately start caching the results.
    ///
    /// This variation may be useful when you don't want to hold a reference to the `body` closure being passed in.
    ///
    /// - Important: Unlike ``init(catching:)``, cancelling a task while reading ``value-5r346`` will **not** propagate into the `body` block provided here.
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter body: The asynchronous closure that either returns a successful value, or throws an error that will be captured.
    public static func cached(catching body: nonisolated(nonsending) @Sendable @escaping () async throws(Failure) -> Success) -> Self {
        let task = Task { try await body() }
        return .init { () async throws(Failure) -> Success in
            do {
                return try await task.value
            } catch {
                throw error as! Failure
            }
        }
    }
    
    /// Initialize an asynchronous value or result with the returned value or thrown error of a closure, and immediately start caching the results.
    ///
    /// This variation may be useful when you don't want to hold a reference to the `body` closure being passed in.
    ///
    /// - Important: Unlike ``init(catching:)``, cancelling a task while reading ``value-5r346`` will **not** propagate into the `resultProducer` block provided here.
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter resultProducer: The closure that asynchronously returns a result.
    public static func cached(async resultProducer: nonisolated(nonsending) @Sendable @escaping () async -> Result<Success, Failure>) -> Self {
        self.cached { () async throws(Failure) -> Success in
            try await resultProducer().get()
        }
    }
}

extension AsyncResult {
    /// Await the value of an asynchronous result, or throw an error if the result ended in failure.
    ///
    /// If the result has been fulfilled, the value is immediately available without suspending.
    public nonisolated(nonsending) var value: Success {
        get async throws(Failure) { try await valueProducer() }
    }
    
    /// Await the result of an asynchronous value.
    ///
    /// If the result has been fulfilled, the result is immediately available without suspending.
    public nonisolated(nonsending) var result: Result<Success, Failure> {
        get async {
            do {
                return .success(try await value)
            } catch {
                return .failure(error)
            }
        }
    }
}

extension AsyncResult where Failure == Never {
    /// Await the value of an asynchronous result.
    public var value: Success {
        get async { await valueProducer() }
    }
}

extension AsyncResult where Success == Void {
    /// Suspend the current task until the async result is fulfilled.
    public func yield() async throws(Failure) {
        try await value
    }
}

extension AsyncResult where Success == Void, Failure == Never {
    /// Suspend the current task until the async result is fulfilled.
    public func yield() async {
        await value
    }
}

extension AsyncResult {
    /// Map the value of a successful result to a new value asynchronously.
    public func map<NewSuccess>(
        _ transform: nonisolated(nonsending) @Sendable @escaping (Success) async -> NewSuccess
    ) -> AsyncResult<NewSuccess, Failure> {
        AsyncResult<NewSuccess, Failure> { () async throws(Failure) -> NewSuccess in
            let value = try await value
            return await transform(value)
        }
    }
    
    /// Map the value of a successful result to a new result asynchronously.
    public func flatMap<NewSuccess>(
        _ transform: nonisolated(nonsending) @Sendable @escaping (Success) async -> Result<NewSuccess, Failure>
    ) -> AsyncResult<NewSuccess, Failure> {
        AsyncResult<NewSuccess, Failure>(async: { () async -> Result<NewSuccess, Failure> in
            do throws(Failure) {
                let value = try await value
                return await transform(value)
            } catch {
                return .failure(error)
            }
        })
    }
    
    /// Map the result to a new result asynchronously.
    public func mapResult<NewSuccess, NewFailure>(
        _ transform: nonisolated(nonsending) @Sendable @escaping (Result<Success, Failure>) async -> Result<NewSuccess, NewFailure>
    ) -> AsyncResult<NewSuccess, NewFailure> {
        AsyncResult<NewSuccess, NewFailure> {
            await transform(result)
        }
    }
    
    /// Map the error of a failing result to a new error asynchronously.
    public func mapError<NewFailure>(
        _ transform: nonisolated(nonsending) @Sendable @escaping (Failure) async -> NewFailure
    ) -> AsyncResult<Success, NewFailure> {
        AsyncResult<Success, NewFailure> { () async throws(NewFailure) -> Success in
            do throws(Failure) {
                return try await value
            } catch {
                throw await transform(error)
            }
        }
    }
    
    /// Map the error of a failing result to a new result asynchronously.
    public func flatMapError<NewFailure>(
        _ transform: nonisolated(nonsending) @Sendable @escaping (Failure) async -> Result<Success, NewFailure>
    ) -> AsyncResult<Success, NewFailure> {
        AsyncResult<Success, NewFailure>(async: { () async -> Result<Success, NewFailure> in
            do throws(Failure) {
                return .success(try await value)
            } catch {
                return await transform(error)
            }
        })
    }
}
