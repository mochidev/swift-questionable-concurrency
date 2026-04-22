//
//  UnfairLockTests.swift
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

@Suite struct UnfairLockTests {
    @Test func basicLockingInFunction() async throws {
        nonisolated(unsafe) var count = 0
        let lock = UnfairLock()
        
        lock.withLock {
            count += 1
        }
        #expect(count == 1)
    }
    
    @Test func basicLockingInClass() async throws {
        class MyClass {
            var count = 0
            let lock = UnfairLock()
            
            func updateCount() {
                lock.withLock {
                    count += 1
                }
            }
        }
        
        let instance = MyClass()
        instance.updateCount()
        #expect(instance.count == 1)
    }
    
    @Test func basicLockingInStruct() async throws {
        struct MyStruct: ~Copyable {
            var count = 0
            let lock = UnfairLock()
            
            mutating func updateCount() {
                lock.withLock {
                    count += 1
                }
            }
        }
        
        var instance = MyStruct()
        instance.updateCount()
        #expect(instance.count == 1)
    }
    
    @Test func lockingIsExclusive() async throws {
        nonisolated(unsafe) var count = 0
        let lock = UnfairLock()
        
        DispatchQueue.concurrentPerform(iterations: 10000) { _ in
            lock.withLock {
                let value = count + 1
                Thread.sleep(forTimeInterval: 0.001)
                count = value
            }
        }
        
        #expect(count == 10000)
    }
    
    #if canImport(Darwin)
    @Test func unsafeUnlock() async throws {
        await #expect(processExitsWith: .signal(9)) {
            let lock = UnfairLock()
            lock.unsafeUnlock()
        }
    }
    #elseif canImport(Glibc)
    @Test func unsafeUnlock() async throws {
        await #expect(processExitsWith: .failure) {
            let lock = UnfairLock()
            lock.unsafeUnlock()
        }
    }
    #endif
    
    #if canImport(Darwin)
    @Test func unresolvedUnsafeLock() async throws {
        await #expect(processExitsWith: .success) {
            let lock = UnfairLock()
            lock.unsafeLock()
        }
    }
    #elseif canImport(Glibc)
    @Test func unresolvedUnsafeLock() async throws {
        await #expect(processExitsWith: .failure) {
            let lock = UnfairLock()
            lock.unsafeLock()
        }
    }
    #endif
    
    #if canImport(Darwin)
    @Test(.timeLimit(.minutes(1))) func unresolvedDoubleUnsafeLock() async throws {
        await #expect(processExitsWith: .signal(9)) {
            let lock = UnfairLock()
            lock.unsafeLock()
            lock.unsafeLock()
        }
    }
    #endif
    
    @Test func lockingDeadlocks() async throws {
        await #expect(processExitsWith: .success) {
            let lock = UnfairLock()
            
            let keepalive = Task.detached {
                /// Make sure the test behaves correctly for at least 5 seconds.
                try await Task.sleep(for: .seconds(5))
            }
            
            DispatchQueue.global().async {
                lock.unsafeLock()
                
                DispatchQueue.global().async {
                    lock.unsafeLock()
                    Issue.record("Should never get past the double lock!")
                    keepalive.cancel()
                }
                
                /// Make sure we keep this thread occupied.
                Thread.sleep(forTimeInterval: 100)
            }
            
            do {
                try await keepalive.value
            } catch {}
        }
    }
}
