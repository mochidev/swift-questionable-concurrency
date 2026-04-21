//
//  AsyncResultTests.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-21.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

import Dispatch
import Foundation
@testable import QuestionableConcurrency
import Testing

@Suite struct AsyncResultTests {
    // MARK: - Instant Fulfillment Tests
    
    @Test func testInstantFulfillment() async throws {
        let asyncResult = AsyncResult {}
        await asyncResult.yield()
    }
    
    @Test func testInstantThrowingFulfillment() async throws {
        let asyncResult = AsyncResult {
            throw TestError()
        }
        /// If this fails, update the documentation in ``AsyncResult`` accordingly.
        #expect(asyncResult as Any is AsyncResult<(), any Error>)
        await #expect(throws: TestError.self) {
            try await asyncResult.yield()
        }
    }
    
    @Test func testInstantTypedThrowingFulfillment() async throws {
        let asyncResult = AsyncResult { () throws(TestError) -> Never in
            throw TestError()
        }
        #expect(asyncResult as Any is AsyncResult<Never, TestError>)
        #expect(await asyncResult.result == .failure(TestError()))
    }
    
    @Test func testInstantSuccess() async throws {
        let asyncResult = AsyncResult { 0 }
        #expect(await asyncResult.value == 0)
    }
    
    @Test func testInstantThrowingSuccess() async throws {
        let asyncResult = AsyncResult<_, TestError> { 0 }
        #expect(try await asyncResult.value == 0)
    }
    
    @Test func testInstantResult() async throws {
        let asyncResult = AsyncResult<_, Never> { .success(0) }
        #expect(await asyncResult.result == .success(0))
    }
    
    @Test func testInstantCasts() async throws {
        do {
            let asyncResult = AsyncResult(Result<Int, TestError>.success(0))
            #expect(asyncResult as Any is AsyncResult<Int, TestError>)
            #expect(await asyncResult.result == .success(0))
        }
        do {
            let asyncResult = AsyncResult(Result<Int, TestError>.failure(TestError()))
            #expect(asyncResult as Any is AsyncResult<Int, TestError>)
            #expect(await asyncResult.result == .failure(TestError()))
        }
        do {
            let asyncResult = AsyncResult<Int, TestError>.success(0)
            #expect(asyncResult as Any is AsyncResult<Int, TestError>)
            #expect(await asyncResult.result == .success(0))
        }
        do {
            let asyncResult = AsyncResult<Int, TestError>.failure(TestError())
            #expect(asyncResult as Any is AsyncResult<Int, TestError>)
            #expect(await asyncResult.result == .failure(TestError()))
        }
        do {
            let asyncResult = AsyncResult.success(0)
            #expect(asyncResult as Any is AsyncResult<Int, Never>)
            #expect(await asyncResult.result == .success(0))
        }
        do {
            let asyncResult = AsyncResult.failure(TestError())
            #expect(asyncResult as Any is AsyncResult<Never, TestError>)
            #expect(await asyncResult.result == .failure(TestError()))
        }
    }
    
    @Test func testInstantMultipleReads() async throws {
        nonisolated(unsafe) var count = 0
        let asyncResult = AsyncResult {
            count += 1
            return 0
        }
        
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        
        #expect(await asyncResult.result == .success(0))
        
        /// Ensure closure was called the expected amount of times:
        #expect(count == 6)
    }
    
    // MARK: - Delayed Fulfillment Tests
    
    @Test func testDelayedFulfillment() async throws {
        let asyncResult = AsyncResult {
            _ = try? await Task.sleep(for: .seconds(0.0001))
        }
        await asyncResult.yield()
    }
    
    @Test func testDelayedThrowingFulfillment() async throws {
        let asyncResult = AsyncResult {
            try? await Task.sleep(for: .seconds(0.0001))
            throw TestError()
        }
        await #expect(throws: TestError.self) {
            try await asyncResult.yield()
        }
    }
    
    @Test func testDelayedTypedThrowingFulfillment() async throws {
        let asyncResult = AsyncResult { () throws(TestError) -> Never in
            try? await Task.sleep(for: .seconds(0.0001))
            throw TestError()
        }
        #expect(await asyncResult.result == .failure(TestError()))
    }
    
    @Test func testDelayedSuccess() async throws {
        let asyncResult = AsyncResult {
            try? await Task.sleep(for: .seconds(0.0001))
            return 0
        }
        #expect(await asyncResult.value == 0)
    }
    
    @Test func testDelayedThrowingSuccess() async throws {
        let asyncResult = AsyncResult<_, TestError> {
            try? await Task.sleep(for: .seconds(0.0001))
            return 0
        }
        #expect(try await asyncResult.value == 0)
    }
    
    @Test func testDelayedResult() async throws {
        let asyncResult = AsyncResult<_, Never> {
            try? await Task.sleep(for: .seconds(0.0001))
            return .success(0)
        }
        #expect(await asyncResult.result == .success(0))
    }
    
    @Test func testDelayedMultipleReads() async throws {
        nonisolated(unsafe) var count = 0
        let asyncResult = AsyncResult {
            try? await Task.sleep(for: .seconds(0.0001))
            count += 1
            return 0
        }
        
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        
        #expect(await asyncResult.result == .success(0))
        
        /// Ensure closure was called the expected amount of times:
        #expect(count == 6)
    }
    
    // MARK: - Cached Tests
    
    @Test func testCachedFulfillment() async throws {
        let asyncResult = AsyncResult.cached {
            _ = try? await Task.sleep(for: .seconds(0.0001))
        }
        await asyncResult.yield()
    }
    
    @Test func testCachedThrowingFulfillment() async throws {
        let asyncResult = AsyncResult.cached {
            try? await Task.sleep(for: .seconds(0.0001))
            throw TestError()
        }
        await #expect(throws: TestError.self) {
            try await asyncResult.yield()
        }
    }
    
    @Test func testCachedTypedThrowingFulfillment() async throws {
        let asyncResult = AsyncResult.cached { () throws(TestError) -> Never in
            try? await Task.sleep(for: .seconds(0.0001))
            throw TestError()
        }
        #expect(await asyncResult.result == .failure(TestError()))
    }
    
    @Test func testCachedSuccess() async throws {
        let asyncResult = AsyncResult.cached {
            try? await Task.sleep(for: .seconds(0.0001))
            return 0
        }
        #expect(await asyncResult.value == 0)
    }
    
    @Test func testCachedThrowingSuccess() async throws {
        let asyncResult = AsyncResult<_, TestError>.cached {
            try? await Task.sleep(for: .seconds(0.0001))
            return 0
        }
        #expect(try await asyncResult.value == 0)
    }
    
    @Test func testCachedResult() async throws {
        let asyncResult = AsyncResult<_, Never>.cached {
            try? await Task.sleep(for: .seconds(0.0001))
            return .success(0)
        }
        #expect(await asyncResult.result == .success(0))
    }
    
    @Test func testCachedMultipleReads() async throws {
        nonisolated(unsafe) var count = 0
        let asyncResult = AsyncResult.cached {
            try? await Task.sleep(for: .seconds(0.0001))
            count += 1
            return 0
        }
        
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        #expect(await asyncResult.value == 0)
        
        #expect(await asyncResult.result == .success(0))
        
        /// Ensure closure was called the expected amount of times:
        #expect(count == 1)
    }
    
    // MARK: - Cancellation Tests
    
    @Test func testCancellationPropagation() async throws {
        let asyncResult = AsyncResult {
            try await Task.sleep(for: .seconds(0.0001))
            return 0
        }
        
        let task = Task {
            do {
                try await Task.sleep(for: .seconds(10))
                Issue.record("Failed to propagate cancellation.")
            } catch {}
            
            return try await asyncResult.value
        }
        task.cancel()
        
        /// Task sees the cancellation:
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        /// External read does not:
        #expect(try await asyncResult.value == 0)
    }
    
    @Test func testCachedCancellationPropagation() async throws {
        let asyncResult = AsyncResult.cached {
            try await Task.sleep(for: .seconds(0.0001))
            return 0
        }
        
        let task = Task {
            do {
                try await Task.sleep(for: .seconds(10))
                Issue.record("Failed to propagate cancellation.")
            } catch {}
            
            return try await asyncResult.value
        }
        task.cancel()
        
        /// Task missed the cancellation:
        #expect(try await task.value == 0)
        /// External read missed the cancellation:
        #expect(try await asyncResult.value == 0)
    }
    
    // MARK: - Map Tests
    
    @Test func testMappingSuccess() async throws {
        let successfulResult = AsyncResult { 0 }.map { success in
            try? await Task.sleep(for: .seconds(0.0001))
            return success + 1
        }
        #expect(await successfulResult.value == 1)
        
        let failingResult = AsyncResult<Int, _> {
            throw TestError()
        }.map { success in
            Issue.record("Should not actually be called.")
            return success + 1
        }
        await #expect(throws: TestError.self) {
            try await failingResult.value
        }
    }
    
    @Test func testFlatMappingSuccess() async throws {
        let successfulResult = AsyncResult { 0 }.flatMap { success in
            try? await Task.sleep(for: .seconds(0.0001))
            return .success(success + 1)
        }
        #expect(await successfulResult.value == 1)
        
        let failingResult = AsyncResult<Int, _> {
            throw TestError()
        }.flatMap { success in
            Issue.record("Should not actually be called.")
            return .success(success + 1)
        }
        await #expect(throws: TestError.self) {
            try await failingResult.value
        }
    }
    
    @Test func testMappingResult() async throws {
        let successfulResult = AsyncResult { 0 }.mapResult { result in
            try? await Task.sleep(for: .seconds(0.0001))
            switch result {
            case .success(let success):
                return Result<_, Never>.success(success + 1)
            case .failure:
                return Result<_, Never>.success(-1)
            }
        }
        #expect(await successfulResult.value == 1)
        
        let failingResult = AsyncResult<Int, _> {
            throw TestError()
        }.mapResult { result in
            try? await Task.sleep(for: .seconds(0.0001))
            switch result {
            case .success(let success):
                return Result<_, Never>.success(success + 1)
            case .failure:
                return Result<_, Never>.success(-1)
            }
        }
        #expect(await failingResult.value == -1)
    }
    
    @Test func testMappingError() async throws {
        let successfulResult = AsyncResult<_, TestError> { 0 }.mapError { error in
            Issue.record("Should not actually be called.")
            return TestError()
        }
        #expect(try await successfulResult.value == 0)
        
        let failingResult = AsyncResult<Int, _> {
            throw TestError()
        }.mapError { error in
            try? await Task.sleep(for: .seconds(0.0001))
            return CancellationError()
        }
        await #expect(throws: CancellationError.self) {
            try await failingResult.value
        }
    }
    
    @Test func testFlatMappingError() async throws {
        let successfulResult = AsyncResult<_, TestError> { 0 }.flatMapError { error in
            Issue.record("Should not actually be called.")
            return .failure(CancellationError())
        }
        #expect(try await successfulResult.value == 0)
        
        let failingResult = AsyncResult<Int, _> {
            throw TestError()
        }.flatMapError { error in
            try? await Task.sleep(for: .seconds(0.0001))
            return .failure(CancellationError())
        }
        await #expect(throws: CancellationError.self) {
            try await failingResult.value
        }
    }
}
