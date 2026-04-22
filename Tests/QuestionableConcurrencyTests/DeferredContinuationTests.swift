//
//  DeferredContinuationTests.swift
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

@Suite struct DeferredContinuationTests {
    @Test func happySuccessReadFirst() async throws {
        for _ in 0...1000 {
            nonisolated(unsafe) var didRead = false
            nonisolated(unsafe) var didWrite = false
            
            let continuation = DeferredContinuation(name: "Test", of: Int.self)
            
            #expect(continuation.name == "Test")
            
            let reader = Task.detached {
                let result = await continuation.future.result
                didRead = true
                #expect(didWrite == true)
                #expect(result == .success(0))
            }
            
            let writer = Task.detached {
                try? await Task.sleep(for: .milliseconds(1))
                didWrite = true
                #expect(didRead == false)
                continuation.resume(with: .success(0))
            }
            
            await reader.value
            await writer.value
        }
    }
    
    @Test func happySuccessWriteFirst() async throws {
        let continuation = DeferredContinuation(name: "Test", of: Int.self)
        
        #expect(continuation.name == "Test")
        continuation.resume(with: .success(0))
        #expect(await continuation.future.result == .success(0))
    }
    
    @Test func happyFailureReadFirst() async throws {
        for _ in 0...1000 {
            nonisolated(unsafe) var didRead = false
            nonisolated(unsafe) var didWrite = false
            
            let continuation = DeferredContinuation(name: "Test", alwaysThrows: TestError.self)
            
            #expect(continuation.name == "Test")
            
            let reader = Task.detached {
                let result = await continuation.future.result
                didRead = true
                #expect(didWrite == true)
                #expect(result == .failure(TestError()))
            }
            
            let writer = Task.detached {
                try? await Task.sleep(for: .milliseconds(1))
                didWrite = true
                #expect(didRead == false)
                continuation.resume(with: .failure(TestError()))
            }
            
            await reader.value
            await writer.value
        }
    }
    
    @Test func happyFailureWriteFirst() async throws {
        let continuation = DeferredContinuation(name: "Test", alwaysThrows: TestError.self)
        
        #expect(continuation.name == "Test")
        continuation.resume(with: .failure(TestError()))
        #expect(await continuation.future.result == .failure(TestError()))
    }
    
    @Test func automaticDebugName() async throws {
        let continuation = DeferredContinuation(of: Void.self, throws: Never.self)
        
        #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<(), Never>")
        continuation.resume(with: .success(()))
    }
    
    @Test func deadlocksIfNeverResumed() async throws {
        await #expect(processExitsWith: .success) {
            let continuation = DeferredContinuation(name: "Test")
            
            let keepalive = Task.detached {
                /// Make sure the test behaves correctly for at least 5 seconds
                try await Task.sleep(for: .seconds(5))
            }
            
            Task {
                await continuation.future.yield()
                Issue.record("Should never get past the un-resumed continuation!")
                keepalive.cancel()
            }
            
            do {
                try await keepalive.value
            } catch {}
        }
    }
    
    #if canImport(Darwin)
    @Test func trapIfResumedMultipleTimes() async throws {
        await #expect(processExitsWith: .signal(5)) {
            let continuation = DeferredContinuation(name: "Test", throws: TestError.self)
            
            continuation.resume(with: .success(()))
            continuation.resume(with: .success(()))
        }
    }
    #elseif canImport(Glibc)
    @Test func trapIfResumedMultipleTimes() async throws {
        await #expect(processExitsWith: .failure) {
            let continuation = DeferredContinuation(name: "Test", throws: TestError.self)
            
            continuation.resume(with: .success(()))
            continuation.resume(with: .success(()))
        }
    }
    #endif
    
    #if canImport(Darwin)
    @Test func trapIfPending() async throws {
        await #expect(processExitsWith: .signal(5)) {
            let continuation = DeferredContinuation(name: "Test")
            
            continuation.trapIfPending()
        }
    }
    #elseif canImport(Glibc)
    @Test func trapIfPending() async throws {
        await #expect(processExitsWith: .failure) {
            let continuation = DeferredContinuation(name: "Test")
            
            continuation.trapIfPending()
        }
    }
    #endif
    
    @Test func doNotTrapIfNotPending() async throws {
        await #expect(processExitsWith: .success) {
            let continuation = DeferredContinuation(name: "Test")
            
            continuation.resume(with: .success(()))
            continuation.trapIfPending()
        }
    }
    
    @Test func initializerTypes() async throws {
        do {
            let continuation = DeferredContinuation(of: Int.self, throws: TestError.self)
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<Int, TestError>")
            continuation.resume(with: .failure(TestError()))
        }
        do {
            let continuation = DeferredContinuation(throws: TestError.self)
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<(), TestError>")
            continuation.resume(with: .failure(TestError()))
        }
        do {
            let continuation = DeferredContinuation(alwaysThrows: TestError.self)
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<Never, TestError>")
            continuation.resume(with: .failure(TestError()))
        }
        do {
            let continuation = DeferredContinuation(of: Int.self)
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<Int, Never>")
            continuation.resume(with: .success(0))
        }
        do {
            let continuation = DeferredContinuation()
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<(), Never>")
            continuation.resume(with: .success(()))
        }
        do {
            let continuation = DeferredContinuation.throwing(of: Int.self)
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<Int, Error>")
            continuation.resume(with: .failure(TestError()))
        }
        do {
            let continuation = DeferredContinuation.throwing()
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<(), Error>")
            continuation.resume(with: .failure(TestError()))
        }
        do {
            let continuation = DeferredContinuation.alwaysThrowing()
            #expect(continuation.name == "QuestionableConcurrency.DeferredContinuation<Never, Error>")
            continuation.resume(with: .failure(TestError()))
        }
    }
}
