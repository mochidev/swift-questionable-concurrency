# QuestionableConcurrency

<p align="center">
    <a href="https://swiftpackageindex.com/mochidev/swift-questionable-concurrency">
        <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmochidev%2Fswift-questionable-concurrency%2Fbadge%3Ftype%3Dswift-versions" alt="Swift Versions" />
    </a>
    <a href="https://swiftpackageindex.com/mochidev/swift-questionable-concurrency">
        <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmochidev%2Fswift-questionable-concurrency%2Fbadge%3Ftype%3Dplatforms" alt="Platforms" />
    </a>
    <a href="https://github.com/mochidev/swift-questionable-concurrency/actions?query=workflow%3A%22Test+QuestionableConcurrency%22">
        <img src="https://github.com/mochidev/swift-questionable-concurrency/workflows/Test%20QuestionableConcurrency/badge.svg" alt="Test Status" />
    </a>
</p>

A swift library for committing crimes against [Structured Concurrency](https://en.wikipedia.org/wiki/Structured_concurrency) (or, you know, helping you implement it 😉).

## Quick Links

- [Documentation](https://swiftpackageindex.com/mochidev/swift-questionable-concurrency/documentation)
- [Updates on Mastodon](https://mastodon.social/tags/QuestionableConcurrency)

## Installation

Add `swift-questionable-concurrency` as a dependency in your `Package.swift` file to start using it. Then, add `import QuestionableConcurrency` to any file you wish to use the library in.

Please check the [releases](https://github.com/mochidev/swift-questionable-concurrency/releases) for recommended versions.

```swift
dependencies: [
    ...
    .package(
        url: "https://github.com/mochidev/swift-questionable-concurrency.git", 
        .upToNextMinor(from: "0.1.1")
    ), // <- Declare the dependency here.
    ...
],
...
targets: [
    .target(
        name: "MyPackage",
        dependencies: [
            ...
            "QuestionableConcurrency", // <- Use the dependency here.
            ...
        ]
    )
]
```

## Usage

### Locks

```swift
import QuestionableConcurrency

class MyClass: @unchecked Sendable {
    let lock: UnfairLock = UnfairLock()
    var count: Int
    
    func updatingCount() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}
```

### Promises and Futures

```swift
import QuestionableConcurrency

actor MyActor {
    var actorStartFuture: Future<Void, Never>
    
    init() {
        let actorStartPromise = Promise(name: "Actor Start", of: Void.self, throws: Never.self)
            actorStartFuture = actorStartPromise.future
        Task {
            actorStartPromise.resume()
        }
    }
    
    func actorDidStart() async {
        await actorStartFuture.value
    }
}
```

## What is `QuestionableConcurrency`?

Swift's [Structured Concurrency](https://en.wikipedia.org/wiki/Structured_concurrency) provides plenty of primitives for writing safer and more reliable concurrent code, but provides few tools for implementing your own APIs that fit into this paradigm. `QuestionableConcurrency` fills this gap with everything you might need to properly cause the chaos your heart desires.

Specifically, promises and futures can be used to reliably test concurrent code in tests, especially when different behavior can be due to subtle timing variations, while locks can be used to ensure unsafe references are properly updated without contention throwing a wrench in your dastardly plans.

## Contributing

Contribution is welcome! Please take a look at the issues already available, or start a new discussion to propose a new feature. Although guarantees can't be made regarding feature requests, PRs that fit within the goals of the project and that _have been discussed beforehand_ are more than welcome!

By submitting a pull request, you represent that you have the right to license your contribution to the community, and agree by submitting the patch that your contributions are licensed under our MIT-Derived No Model Training License (see [LICENSE](LICENSE)). Unfortunately, this limits contribution of most generated code. If you are submitting locally generated code in your patch, you are expected to make it clear which models were used, how much of the patch was generated, and maintain that you, the author, transformed that generated code substantially enough to hold the copyright to that patch and are capable of transferring those rights over to the community.

Please make sure that all submissions have clean commit histories, are well documented, and thoroughly tested. **Please rebase your PR** before submission rather than merge in `main`. Linear histories are required, so merge commits in PRs will not be accepted.

## Support

To support this project, consider following [@dimitribouniol](https://mastodon.social/@dimitribouniol) on Mastodon, listening to Spencer and Dimitri on [Code Completion](https://mastodon.social/@codecompletion), or downloading our contributors’ apps:
- [Jiiiii](https://jiiiii.app/)
- [Not Phở](https://notpho.app/)
