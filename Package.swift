// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GapwiseCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "GapwiseCore", targets: ["GapwiseCore"])
    ],
    targets: [
        .target(
            name: "GapwiseCore",
            path: "Gapwise/Core"
        ),
        .testTarget(
            name: "GapwiseCoreTests",
            dependencies: ["GapwiseCore"],
            path: "GapwiseTests/Core",
            resources: [.process("Fixtures")]
        ),
    ]
)
