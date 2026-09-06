// swift-tools-version: 5.9
import PackageDescription

// OutbreakEngine is a pure-Swift, platform-independent simulation module.
// It imports nothing from SwiftUI / UIKit so the entire rule set can be
// unit-tested with `swift test` without a simulator (see docs/PRE_SUBMISSION_CHECKLIST.md).
let package = Package(
    name: "OutbreakEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "OutbreakEngine", targets: ["OutbreakEngine"])
    ],
    targets: [
        .target(name: "OutbreakEngine"),
        .testTarget(name: "OutbreakEngineTests", dependencies: ["OutbreakEngine"])
    ]
)
