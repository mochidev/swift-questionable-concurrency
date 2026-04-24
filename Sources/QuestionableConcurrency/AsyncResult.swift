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
    #if compiler(>=6.2)
    let valueProducer: nonisolated(nonsending) @Sendable () async throws(Failure) -> Success
    #elseif compiler(>=6.0)
    let valueProducer: @Sendable () async throws(Failure) -> Success
    #else
    let valueProducer: @Sendable () async throws -> Success
    #endif
    
    /// Initialize an asynchronous value or result with the returned value or thrown error of a closure.
    ///
    /// - Important: If a task reading a ``value-5r346`` is cancelled, cancellation will propagate into the `body` block provided here for that read operation.
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter body: The asynchronous closure that either returns a successful value, or throws an error that will be captured.
    #if compiler(>=6.2)
    public init(catching body: nonisolated(nonsending) @Sendable @escaping () async throws(Failure) -> Success) {
        self.valueProducer = body
    }
    #elseif compiler(>=6.0)
    public init(catching body: @Sendable @escaping () async throws(Failure) -> Success) {
        self.valueProducer = body
    }
    #else
    public init(catching body: @Sendable @escaping () async throws -> Success) where Failure: Error {
        self.valueProducer = body
    }
    public init(catching body: @Sendable @escaping () async -> Success) where Failure == Never {
        self.valueProducer = body
    }
    #endif
}

extension AsyncResult {
    /// Initialize an asynchronous value or result with the returned result of a closure.
    ///
    /// - Important: If a task reading a ``value-5r346`` is cancelled, cancellation will propagate into the `resultProducer` block provided here for that read operation.
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter resultProducer: The closure that asynchronously returns a result.
    #if compiler(>=6.2)
    public init(async resultProducer: nonisolated(nonsending) @Sendable @escaping () async -> Result<Success, Failure>) {
        self.init { () async throws(Failure) -> Success in
            try await resultProducer().get()
        }
    }
    #elseif compiler(>=6.0)
    public init(async resultProducer: @Sendable @escaping () async -> Result<Success, Failure>) {
        self.init { () async throws(Failure) -> Success in
            try await resultProducer().get()
        }
    }
    #else
    public init(async resultProducer: @Sendable @escaping () async -> Result<Success, Failure>) where Failure: Error {
        self.init {
            try await resultProducer().get()
        }
    }
    public init(async resultProducer: @Sendable @escaping () async -> Result<Success, Failure>) where Failure == Never {
        self.init {
            try! await resultProducer().get()
        }
    }
    #endif
    
    /// Initialize an asynchronous value or result with a synchronous ``/Swift/Result``.
    ///
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter result: The result to wrap.
    #if compiler(>=6.0)
    public init(_ result: Result<Success, Failure>) {
        self.init { () throws(Failure) -> Success in
            try result.get()
        }
    }
    #else
    public init(_ result: Result<Success, Failure>) {
        self.init {
            try result.get()
        }
    }
    #endif
    
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
    #if compiler(>=6.2)
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
    #elseif compiler(>=6.0)
    public static func cached(catching body: @Sendable @escaping () async throws(Failure) -> Success) -> Self {
        let task = Task { try await body() }
        return .init { () async throws(Failure) -> Success in
            do {
                return try await task.value
            } catch {
                throw error as! Failure
            }
        }
    }
    #else
    public static func cached(catching body: @Sendable @escaping () async throws -> Success) -> Self where Failure: Error {
        let task = Task { try await body() }
        return .init {
            try await task.value
        }
    }
    public static func cached(catching body: @Sendable @escaping () async -> Success) -> Self where Failure == Never {
        let task = Task { await body() }
        return .init {
            await task.value
        }
    }
    #endif
    
    /// Initialize an asynchronous value or result with the returned value or thrown error of a closure, and immediately start caching the results.
    ///
    /// This variation may be useful when you don't want to hold a reference to the `body` closure being passed in.
    ///
    /// - Important: Unlike ``init(catching:)``, cancelling a task while reading ``value-5r346`` will **not** propagate into the `resultProducer` block provided here.
    /// - SeeAlso: ``AsyncResult``
    /// - Parameter resultProducer: The closure that asynchronously returns a result.
    #if compiler(>=6.2)
    public static func cached(async resultProducer: nonisolated(nonsending) @Sendable @escaping () async -> Result<Success, Failure>) -> Self {
        self.cached { () async throws(Failure) -> Success in
            try await resultProducer().get()
        }
    }
    #elseif compiler(>=6.0)
    public static func cached(async resultProducer: @Sendable @escaping () async -> Result<Success, Failure>) -> Self {
        self.cached { () async throws(Failure) -> Success in
            try await resultProducer().get()
        }
    }
    #else
    public static func cached(async resultProducer: @Sendable @escaping () async -> Result<Success, Failure>) -> Self {
        self.cached {
            try await resultProducer().get()
        }
    }
    #endif
}

extension AsyncResult {
    /// Await the value of an asynchronous result, or throw an error if the result ended in failure.
    ///
    /// If the result has been fulfilled, the value is immediately available without suspending.
    #if compiler(>=6.2)
    public nonisolated(nonsending) var value: Success {
        get async throws(Failure) { try await valueProducer() }
    }
    #elseif compiler(>=6.0)
    public nonisolated var value: Success {
        get async throws(Failure) { try await valueProducer() }
    }
    #else
    public nonisolated var value: Success {
        get async throws { try await valueProducer() }
    }
    #endif
    
    /// Await the result of an asynchronous value.
    ///
    /// If the result has been fulfilled, the result is immediately available without suspending.
    #if compiler(>=6.2)
    public nonisolated(nonsending) var result: Result<Success, Failure> {
        get async {
            do {
                return .success(try await value)
            } catch {
                return .failure(error)
            }
        }
    }
    #elseif compiler(>=6.0)
    public nonisolated var result: Result<Success, Failure> {
        get async {
            do {
                return .success(try await value)
            } catch {
                return .failure(error)
            }
        }
    }
    #else
    public nonisolated var result: Result<Success, Failure> {
        get async {
            do {
                return .success(try await value)
            } catch {
                return .failure(error as! Failure)
            }
        }
    }
    #endif
}

extension AsyncResult where Failure == Never {
    /// Await the value of an asynchronous result.
    #if compiler(>=6.0)
    public var value: Success {
        get async { await valueProducer() }
    }
    #else
    public var value: Success {
        get async { try! await valueProducer() }
    }
    #endif
}

extension AsyncResult where Success == Void {
    /// Suspend the current task until the async result is fulfilled.
    #if compiler(>=6.0)
    public func yield() async throws(Failure) {
        try await value
    }
    #else
    public func yield() async throws {
        try await value
    }
    #endif
}

extension AsyncResult where Success == Void, Failure == Never {
    /// Suspend the current task until the async result is fulfilled.
    public func yield() async {
        await value
    }
}

#if compiler(<5.10) || compiler(>=6.0) /// There's an issue compiling the following on Swift 5.10.1 for some unknown reason…
extension AsyncResult {
    /// Map the value of a successful result to a new value asynchronously.
    #if compiler(>=6.2)
    public func map<NewSuccess>(
        _ transform: nonisolated(nonsending) @Sendable @escaping (Success) async -> NewSuccess
    ) -> AsyncResult<NewSuccess, Failure> {
        AsyncResult<NewSuccess, Failure> { () async throws(Failure) -> NewSuccess in
            let value = try await value
            return await transform(value)
        }
    }
    #elseif compiler(>=6.0)
    public func map<NewSuccess>(
        _ transform: @Sendable @escaping (Success) async -> NewSuccess
    ) -> AsyncResult<NewSuccess, Failure> {
        AsyncResult<NewSuccess, Failure> { () async throws(Failure) -> NewSuccess in
            let value = try await value
            return await transform(value)
        }
    }
    #else
    public func map<NewSuccess>(
        _ transform: @Sendable @escaping (Success) async -> NewSuccess
    ) -> AsyncResult<NewSuccess, Failure> {
        AsyncResult<NewSuccess, Failure> {
            let value = try await value
            return await transform(value)
        }
    }
    #endif
    
    /// Map the value of a successful result to a new result asynchronously.
    #if compiler(>=6.2)
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
    #elseif compiler(>=6.0)
    public func flatMap<NewSuccess>(
        _ transform: @Sendable @escaping (Success) async -> Result<NewSuccess, Failure>
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
    #else
    public func flatMap<NewSuccess>(
        _ transform: @Sendable @escaping (Success) async -> Result<NewSuccess, Failure>
    ) -> AsyncResult<NewSuccess, Failure> {
        AsyncResult<NewSuccess, Failure>(async: {
            do {
                let value = try await value
                return await transform(value)
            } catch {
                return .failure(error as! Failure)
            }
        })
    }
    #endif
    
    /// Map the result to a new result asynchronously.
    #if compiler(>=6.2)
    public func mapResult<NewSuccess, NewFailure>(
        _ transform: nonisolated(nonsending) @Sendable @escaping (Result<Success, Failure>) async -> Result<NewSuccess, NewFailure>
    ) -> AsyncResult<NewSuccess, NewFailure> {
        AsyncResult<NewSuccess, NewFailure> {
            await transform(result)
        }
    }
    #else
    public func mapResult<NewSuccess, NewFailure>(
        _ transform: @Sendable @escaping (Result<Success, Failure>) async -> Result<NewSuccess, NewFailure>
    ) -> AsyncResult<NewSuccess, NewFailure> {
        AsyncResult<NewSuccess, NewFailure> {
            await transform(result)
        }
    }
    #endif
    
    /// Map the error of a failing result to a new error asynchronously.
    #if compiler(>=6.2)
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
    #elseif compiler(>=6.0)
    public func mapError<NewFailure>(
        _ transform: @Sendable @escaping (Failure) async -> NewFailure
    ) -> AsyncResult<Success, NewFailure> {
        AsyncResult<Success, NewFailure> { () async throws(NewFailure) -> Success in
            do throws(Failure) {
                return try await value
            } catch {
                throw await transform(error)
            }
        }
    }
    #else
    public func mapError<NewFailure>(
        _ transform: @Sendable @escaping (Failure) async -> NewFailure
    ) -> AsyncResult<Success, NewFailure> {
        AsyncResult<Success, NewFailure> {
            do {
                return .success(try await value)
            } catch {
                return .failure(await transform(error as! Failure))
            }
        }
    }
    #endif
    
    /// Map the error of a failing result to a new result asynchronously.
    #if compiler(>=6.2)
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
    #elseif compiler(>=6.0)
    public func flatMapError<NewFailure>(
        _ transform: @Sendable @escaping (Failure) async -> Result<Success, NewFailure>
    ) -> AsyncResult<Success, NewFailure> {
        AsyncResult<Success, NewFailure>(async: { () async -> Result<Success, NewFailure> in
            do throws(Failure) {
                return .success(try await value)
            } catch {
                return await transform(error)
            }
        })
    }
    #else
    public func flatMapError<NewFailure>(
        _ transform: @Sendable @escaping (Failure) async -> Result<Success, NewFailure>
    ) -> AsyncResult<Success, NewFailure> {
        AsyncResult<Success, NewFailure>(async: {
            do {
                return .success(try await value)
            } catch {
                return await transform(error as! Failure)
            }
        })
    }
    #endif
}
#endif
