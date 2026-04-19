//
//  AsyncResult.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-16.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

/// An asynchronous value or result that is fullfilled by the closure passed when initialized.
public struct AsyncResult<
    Success: Sendable,
    Failure: Error
>: Sendable {
    /// The internal producer that vends the value as soon as it is unsuspended by its associated promise.
    let valueProducer: nonisolated(nonsending) @Sendable () async throws(Failure) -> Success
    
    public init(catching body: nonisolated(nonsending) @Sendable @escaping () async throws(Failure) -> Success) {
        self.valueProducer = body
    }
    
    public init(async resultProducer: nonisolated(nonsending) @Sendable @escaping () async -> Result<Success, Failure>) {
        self.valueProducer = { () async throws(Failure) -> Success in
            try await resultProducer().get()
        }
    }
}

extension AsyncResult {
    public nonisolated(nonsending) var value: Success {
        get async throws(Failure) { try await valueProducer() }
    }
    
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
    public var value: Success {
        get async { await valueProducer() }
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
