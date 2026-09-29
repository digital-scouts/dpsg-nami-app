import Foundation
import NamiAiEvalKit
import NamiAiKit

enum EvalCLIRuntime {
  /// ios/NamiAiKit/Sources/NamiAiEvalCLI/<file> -> repo root is five levels up, same depth/
  /// technique as NamiAiEvalTests.repoRootURL() (ios/NamiAiKit/Tests/NamiAiKitTests/<file>) - so
  /// default paths work regardless of the caller's working directory when invoking `swift run`.
  static func repoRootURL() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 {
      url.deleteLastPathComponent()
    }
    return url
  }

  static func newRunId(now: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: now)
  }
}

/// Wires EvalSessionDriving to the real NamiAiAssistant: the only place in this CLI that
/// actually calls into NamiAiKit's FoundationModels-backed pipeline. Uses EvalAsyncBridge to
/// turn the completion-based calls into bounded `async` calls (--timeout-seconds).
struct LiveEvalSessionDriver: EvalSessionDriving {
  let timeoutSeconds: Double
  let verbose: Bool

  func startSession(selfCorrectionEnabled: Bool) async -> EvalAsyncOutcome<String> {
    await EvalAsyncBridge.awaiting(timeoutSeconds: timeoutSeconds) { completion in
      NamiAiAssistant.startSession(
        selfCorrectionEnabled: selfCorrectionEnabled, completion: completion)
    }
  }

  func streamRespond(sessionId: String, to prompt: String) async -> EvalAsyncOutcome<NamiAiAnswer> {
    await EvalAsyncBridge.awaiting(timeoutSeconds: timeoutSeconds) { completion in
      NamiAiAssistant.streamRespond(
        sessionId: sessionId, to: prompt,
        onPartial: { partial in
          guard verbose else { return }
          print("  ...\(partial.suffix(80))")
        },
        onRevising: {
          guard verbose else { return }
          print("  [wird ueberprueft - Selbstkorrektur laeuft]")
        },
        onComplete: completion)
    }
  }

  /// Best-effort, same as every other NamiAiAssistant caller (see its doc comment) - fires the
  /// teardown and moves on without waiting for it, since a missing/already-gone session is not
  /// an error and the next session gets its own fresh id regardless.
  func endSession(sessionId: String) async {
    NamiAiAssistant.endSession(sessionId: sessionId)
  }
}
