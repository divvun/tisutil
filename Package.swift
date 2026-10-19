// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tisutil",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TISKit", targets: ["TISKit"]),
        .executable(name: "tisutil", targets: ["tisutil"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "TISKit"),
        .target(
            name: "TISUtilCommands",
            dependencies: [
                "TISKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/Commands"
        ),
        .executableTarget(name: "tisutil", dependencies: ["TISUtilCommands"]),
        .testTarget(name: "TISKitTests", dependencies: ["TISKit"]),
        .testTarget(
            name: "TISUtilCommandsTests",
            dependencies: ["TISUtilCommands", "TISKit"],
            path: "Tests/CommandsTests"
        ),
    ]
)
