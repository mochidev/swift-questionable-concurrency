//
//  DeferredContinuation.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-19.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

public actor DeferredContinuation<
    Success: Sendable,
    Failure: Error
>: Sendable {
    #if DEBUG
    typealias Continuation = CheckedContinuation<Success, any Error>
    #else
    typealias Continuation = UnsafeContinuation<Success, any Error>
    #endif
    
    enum State: Sendable {
        case pending([Continuation])
        case fulfilled(Result<Success, Failure>)
    }
    
    public let name: String
    let lock: UnfairLock = UnfairLock()
    nonisolated(unsafe) var state: State = .pending([])
    
    public init(
        name continuationName: String? = nil,
        of successType: Success.Type = Success.self,
        throws failureType: Failure.Type = Failure.self
    ) {
        self.name = continuationName ?? "QuestionableConcurrency.DeferredContinuation<\(successType), \(failureType)>"
    }
    
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
