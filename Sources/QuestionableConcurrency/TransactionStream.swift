//
//  TransactionStream.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-07-25.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

/// A serialized stream of transactions that are always performed in order.
public actor TransactionStream: Sendable {
    @usableFromInline
    var lastTransactionResult: AsyncResult<Void, Never>?
    
    /// Initialize a new transaction stream.
    public init () {}
    
    /// Aquire a spot in the stream and await our turn.
    /// - Returns: A promise that must be fullfilled to allow the next caller to resume.
    @usableFromInline
    func next() async -> Promise<Void, Never> {
        /// Replace the future with an upcoming one so we save our spot in line.
        let isTransactingPromise = Promise(name: "TransactionStream")
        let lastFuture = lastTransactionResult
        lastTransactionResult = isTransactingPromise.future
        
        /// Then, await the completion of the last transaction before starting the new one.
        await lastFuture?.yield()
        
        return isTransactingPromise
    }
    
    /// Perform the specified body operation as a serializable transaction in calling order.
    /// - Parameters:
    ///   - actor: The isolation context to run the reciever on.
    ///   - body: The operation to immediately perform on the transaction stream when all other transactions are finished.
    /// - Returns: The result of the operation or a thrown error if it failed.
    @inlinable
    public func withTransaction<T: Sendable, Failure: Error>(
        isolation actor: isolated (any Actor)? = #isolation,
        _ body: () async throws(Failure) -> T
    ) async throws(Failure) -> T {
        /// Aquire our spot in line and wait for our turn.
        let isTransactingPromise = await next()
        
        do {
            /// Perform the operation regardless of the outcome.
            let result = try await body()
            
            /// Resume the promise so the next transaction can take place.
            isTransactingPromise.resume()
            
            /// Return the result of the operation to the caller.
            return result
        } catch {
            /// Resume the promise so the next transaction can take place.
            isTransactingPromise.resume()
            
            throw error
        }
    }
}
