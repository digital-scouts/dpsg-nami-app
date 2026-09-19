// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "NamiAiKit",
  platforms: [.iOS(.v15), .macOS(.v26)],
  products: [
    .library(name: "NamiAiKit", targets: ["NamiAiKit"])
  ],
  targets: [
    .target(
      name: "NamiAiKit",
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
      name: "NamiAiKitTests",
      dependencies: ["NamiAiKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
  ]
)
