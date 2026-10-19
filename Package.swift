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
            name: "TisutilCommands",
            dependencies: [
                "TISKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(name: "tisutil", dependencies: ["TisutilCommands"]),
        .testTarget(name: "TISKitTests", dependencies: ["TISKit"]),
        .testTarget(name: "TisutilCommandsTests", dependencies: ["TisutilCommands", "TISKit"]),
    ]
)
