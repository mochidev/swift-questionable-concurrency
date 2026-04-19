//
//  Promise.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-16.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

public struct Promise<
    Success: Sendable,
    Failure: Error
>: ~Copyable, Sendable {
    
    public let name: String
    let continuation: DeferredContinuation<Success, Failure>
    public let future: Future<Success, Failure>
    
    public init(
        name promiseName: String? = nil,
        of successType: Success.Type = Success.self,
        throws failureType: Failure.Type = Failure.self
    ) {
        let promiseName = promiseName ?? "QuestionableConcurrency.Promise<\(successType), \(failureType)>"
        name = promiseName
        continuation = DeferredContinuation(name: promiseName)
        future = AsyncResult { [continuation] () async throws(Failure) -> Success in
            try await continuation.value
        }
    }
    
    deinit {
        /// If our continuation is still pending, the promise was never resumed, so trap at runtime.
        continuation.trapIfPending()
    }
    
    public consuming func resume(with result: sending Result<Success, Failure>) {
        continuation.resume(with: result)
    }
}

extension Promise {
    public consuming func resume(returning value: sending Success) {
        resume(with: .success(value))
    }
    
    public consuming func resume(throwing error: Failure) {
        resume(with: .failure(error))
    }
    
    public consuming func resume<LocalFailure>(with result: sending Result<Success, LocalFailure>) where Failure == any Error, LocalFailure: Error {
        resume(with: result.mapError { $0 as Failure })
    }
    
    public consuming func resume() where Success == () {
        resume(with: .success(()))
    }
}
