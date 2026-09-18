// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NamiAiKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "NamiAiKit", targets: ["NamiAiKit"])
    ],
    targets: [
        .target(
            name: "NamiAiKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NamiAiKitTests",
            dependencies: ["NamiAiKit"]
        ),
    ]
)
