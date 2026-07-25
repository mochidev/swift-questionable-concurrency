//
//  TransactionStreamTests.swift
//  https://github.com/mochidev/swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-07-25.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19
//

import Dispatch
import Foundation
@testable import QuestionableConcurrency
import Testing

@Suite struct TransactionStreamTests {
    @Test func testSynchronousAccess() async throws {
        let transactionStream = TransactionStream()
        var tasks: [Task<Void, Never>] = []
        
        nonisolated(unsafe) var count = 0
        nonisolated(unsafe) var lastStartedIndex = 0
        for index in 0..<1000 {
            tasks.append(Task {
                let result = await transactionStream.withTransaction {
                    lastStartedIndex = index
                    try? await Task.sleep(for: .seconds(Double.random(in: 0.0001...0.001)))
                    count += 1
                    #expect(lastStartedIndex == index)
                    return index
                }
                
                #expect(result == index)
            })
        }
        
        for task in tasks {
            await task.value
        }
        #expect(count == 1000)
    }
}
