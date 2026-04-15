// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

//
//  Package.swift
//  swift-questionable-concurrency
//
//  Created by Dimitri Bouniol on 2026-04-15.
//  Copyright © 2026 Mochi Development, Inc. All rights reserved.
//  swift-questionable-concurrency-watermark: 20E931FAE8CA4B05929CA61A82D9DA19

import PackageDescription

let swiftSettings: [PackageDescription.SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
]

let package = Package(
    name: "swift-questionable-concurrency",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "QuestionableConcurrency",
            targets: ["QuestionableConcurrency"]
        ),
    ],
    targets: [
        .target(
            name: "QuestionableConcurrency",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "QuestionableConcurrencyTests",
            dependencies: ["QuestionableConcurrency"],
            swiftSettings: swiftSettings
        ),
    ]
)
