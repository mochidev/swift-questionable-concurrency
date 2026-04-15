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
    .package(
        url: "https://github.com/mochidev/swift-questionable-concurrency.git", 
        .upToNextMinor(from: "0.1.0")
    ),
],
...
targets: [
    .target(
        name: "MyPackage",
        dependencies: [
            "QuestionableConcurrency",
        ]
    )
]
```

## Usage

TBD

## What is `QuestionableConcurrency`?

TBD

## Contributing

Contribution is welcome! Please take a look at the issues already available, or start a new discussion to propose a new feature. Although guarantees can't be made regarding feature requests, PRs that fit within the goals of the project and that have been discussed beforehand are more than welcome!

Please make sure that all submissions have clean commit histories, are well documented, and thoroughly tested. **Please rebase your PR** before submission rather than merge in `main`. Linear histories are required, so merge commits in PRs will not be accepted.

## Support

To support this project, consider following [@dimitribouniol](https://mastodon.social/@dimitribouniol) on Mastodon, listening to Spencer and Dimitri on [Code Completion](https://mastodon.social/@codecompletion), or downloading our contributors’ apps:
- [Jiiiii](https://jiiiii.app/)
- [Not Phở](https://notpho.app/)
