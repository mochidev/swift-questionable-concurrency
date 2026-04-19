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
    typealias Continuation = CheckedContinuation<Success, any Error>
    
    let name: String
    var continuation: Continuation?
    public let future: Future<Success, Failure>
    
    public init(
        name: String? = nil,
        of successType: Success.Type = Success.self,
        throws failureType: Failure.Type = Failure.self,
        isolation: isolated (any Actor)? = #isolation,
        function: String = #function
    ) async {
        let promiseName = name ?? "QuestionableConcurrency.Promise<\(successType), \(failureType)>"
        self.name = promiseName
        var task: Task<Success, any Error>?
        continuation = await withCheckedContinuation { factoryContinuation in
            task = Task(name: promiseName) {
                try await withCheckedThrowingContinuation { taskContinuation in
                    factoryContinuation.resume(returning: taskContinuation)
                }
            }
        }
        future = AsyncResult { [task] () async throws(Failure) -> Success in
            do {
                return try await task!.value
            } catch {
                throw error as! Failure
            }
        }
    }
    
    deinit {
        /// If we still have a continuation, then trap at runtime since the promise was forgotten.
        guard continuation != nil else { return }
        fatalError("\(name) was dropped without being resumed.")
    }
    
    public consuming func resume(with result: sending Result<Success, Failure>) {
        continuation!.resume(with: result)
        continuation = nil
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
