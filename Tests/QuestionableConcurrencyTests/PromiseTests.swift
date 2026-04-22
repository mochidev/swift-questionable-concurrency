//
//  PromiseTests.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-22.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

import Dispatch
import Foundation
@testable import QuestionableConcurrency
import Testing

@Suite struct PromiseTests {
    @Test func happySuccessReadFirst() async throws {
        for _ in 0...1000 {
            nonisolated(unsafe) var didRead = false
            nonisolated(unsafe) var didWrite = false
            
            let promise = Promise(name: "Test", of: Int.self, throws: TestError.self)
            let future = promise.future
            
            #expect(promise.name == "Test")
            
            let reader = Task.detached {
                let result = await future.result
                didRead = true
                #expect(didWrite == true)
                #expect(result == .failure(TestError()))
            }
            
            var optionalPromise: Promise? = promise
            let writer = Task.detached {
                try? await Task.sleep(for: .milliseconds(1))
                didWrite = true
                #expect(didRead == false)
                optionalPromise.take()?.resume(with: .failure(TestError()))
            }
            
            await reader.value
            await writer.value
        }
    }
    
    @Test func happySuccessWriteFirst() async throws {
        let promise = Promise(name: "Test", of: Int.self)
        let future = promise.future
        
        #expect(promise.name == "Test")
        promise.resume(with: .success(0))
        #expect(await future.result == .success(0))
    }
    
    @Test func happyFailureReadFirst() async throws {
        for _ in 0...1000 {
            nonisolated(unsafe) var didRead = false
            nonisolated(unsafe) var didWrite = false
            
            let promise = Promise(name: "Test", alwaysThrows: TestError.self)
            let future = promise.future
            
            #expect(promise.name == "Test")
            
            let reader = Task.detached {
                let result = await future.result
                didRead = true
                #expect(didWrite == true)
                #expect(result == .failure(TestError()))
            }
            
            var optionalPromise: Promise? = promise
            let writer = Task.detached {
                try? await Task.sleep(for: .milliseconds(1))
                didWrite = true
                #expect(didRead == false)
                optionalPromise.take()?.resume(with: .failure(TestError()))
            }
            
            await reader.value
            await writer.value
        }
    }
    
    @Test func happyFailureWriteFirst() async throws {
        let promise = Promise(name: "Test", alwaysThrows: TestError.self)
        let future = promise.future
        
        #expect(promise.name == "Test")
        promise.resume(with: .failure(TestError()))
        #expect(await future.result == .failure(TestError()))
    }
    
    @Test func automaticDebugName() async throws {
        let promise = Promise(of: Void.self, throws: Never.self)
        
        #expect(promise.name == "QuestionableConcurrency.Promise<(), Never>")
        promise.resume(with: .success(()))
    }
    
    @Test func deadlocksIfNeverResumed() async throws {
        await #expect(processExitsWith: .success) {
            let promise = Promise(name: "Test")
            
            let keepalive = Task.detached {
                /// Make sure the test behaves correctly for at least 5 seconds
                try await Task.sleep(for: .seconds(5))
            }
            
            Task {
                await promise.future.yield()
                Issue.record("Should never get past the un-resumed promise!")
                keepalive.cancel()
            }
            
            do {
                try await keepalive.value
            } catch {}
        }
    }
    
    @Test func trapIfPending() async throws {
        await #expect(processExitsWith: .signal(5)) {
            let promise = Promise(name: "Test")
            let _ = promise.future
        }
    }
    
    @Test func doNotTrapIfNotPending() async throws {
        await #expect(processExitsWith: .success) {
            let promise = Promise(name: "Test")
            
            promise.resume(with: .success(()))
        }
    }
    
    @Test func initializerTypes() async throws {
        do {
            let promise = Promise(of: Int.self, throws: TestError.self)
            #expect(promise.name == "QuestionableConcurrency.Promise<Int, TestError>")
            promise.resume(throwing: TestError())
        }
        do {
            let promise = Promise(throws: TestError.self)
            #expect(promise.name == "QuestionableConcurrency.Promise<(), TestError>")
            promise.resume(throwing: TestError())
        }
        do {
            let promise = Promise(alwaysThrows: TestError.self)
            #expect(promise.name == "QuestionableConcurrency.Promise<Never, TestError>")
            promise.resume(throwing: TestError())
        }
        do {
            let promise = Promise(of: Int.self)
            #expect(promise.name == "QuestionableConcurrency.Promise<Int, Never>")
            promise.resume(returning: 0)
        }
        do {
            let promise = Promise()
            #expect(promise.name == "QuestionableConcurrency.Promise<(), Never>")
            promise.resume()
        }
        do {
            let promise = Promise.throwing(of: Int.self)
            #expect(promise.name == "QuestionableConcurrency.Promise<Int, Error>")
            promise.resume(with: .failure(TestError()))
        }
        do {
            let promise = Promise.throwing()
            #expect(promise.name == "QuestionableConcurrency.Promise<(), Error>")
            promise.resume(with: Result<Void, TestError>.failure(TestError()))
        }
        do {
            let promise = Promise.alwaysThrowing()
            #expect(promise.name == "QuestionableConcurrency.Promise<Never, Error>")
            promise.resume(with: .failure(TestError()))
        }
    }
}
