// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "NamiAiKit",
  platforms: [.iOS(.v15), .macOS(.v26)],
  products: [
    .library(name: "NamiAiKit", targets: ["NamiAiKit"]),
    .library(name: "NamiAiEvalKit", targets: ["NamiAiEvalKit"]),
    .executable(name: "nami-ai-eval", targets: ["NamiAiEvalCLI"]),
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
    // Model-independent eval-harness logic (fixture decoding, source/guardrail matching,
    // JSONL log building, turn orchestration) - depends only on NamiAiKit's public API, so it
    // compiles and is unit-testable on any machine, without FoundationModels/Apple Intelligence.
    // See chat_ai/eval/README.md for how this fits alongside the manual eval runbook.
    .target(
      name: "NamiAiEvalKit",
      dependencies: ["NamiAiKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
      name: "NamiAiEvalKitTests",
      dependencies: ["NamiAiEvalKit", "NamiAiKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    // Thin CLI wrapper: argument parsing, wiring NamiAiEvalKit's orchestration against the
    // real NamiAiAssistant, filesystem I/O. Runs only locally on a Mac with Apple Intelligence
    // enabled (same FoundationModels constraint as the rest of this package) - not part of CI.
    .executableTarget(
      name: "NamiAiEvalCLI",
      dependencies: ["NamiAiKit", "NamiAiEvalKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
  ]
)
