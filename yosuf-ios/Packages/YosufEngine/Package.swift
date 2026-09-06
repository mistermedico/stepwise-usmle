// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YosufEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "YosufEngine", targets: ["YosufEngine"])
    ],
    targets: [
        .target(
            name: "YosufEngine",
            path: "Sources/YosufEngine"
        ),
        .testTarget(
            name: "YosufEngineTests",
            dependencies: ["YosufEngine"],
            path: "Tests/YosufEngineTests"
        )
    ]
)
