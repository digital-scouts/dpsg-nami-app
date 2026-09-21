import Foundation
import NamiAiKit

/// Outcome of an awaited completion-handler call. Kept distinct from NamiAiError (rather than
/// adding a NamiAiError.timedOut case) so this eval-only concern never touches NamiAiKit's
/// public error surface - a real, non-eval caller has no use for "the CLI's own timeout fired".
public enum EvalAsyncOutcome<T: Sendable>: Sendable {
  case success(T)
  case failure(NamiAiError)
  case timedOut
}

/// Every NamiAiAssistant entry point (startSession/streamRespond/endSession) is completion-
/// based, since it's built for a UI event loop, not a script. This is the one generic adapter
/// the CLI needs to turn those into `async` calls with a bounded wait - a model call can
/// pathologically hang (see chat_ai/eval/README.md "Bekannte Grenzen" on non-determinism), and a
/// batch run over dozens of fixtures must not be able to hang forever on a single one.
public enum EvalAsyncBridge {
  /// Races `operation`'s completion against a `timeoutSeconds` sleep; whichever finishes first
  /// wins and the other is cancelled. Purely generic over Result<T, NamiAiError>, so it's
  /// testable with a fake completion-calling function - no FoundationModels/real model needed
  /// (see EvalAsyncBridgeTests).
  public static func awaiting<T: Sendable>(
    timeoutSeconds: Double,
    _ operation: @escaping (@escaping (Result<T, NamiAiError>) -> Void) -> Void
  ) async -> EvalAsyncOutcome<T> {
    await withTaskGroup(of: EvalAsyncOutcome<T>.self) { group in
      group.addTask {
        await withCheckedContinuation {
          (continuation: CheckedContinuation<EvalAsyncOutcome<T>, Never>) in
          operation { result in
            switch result {
            case .success(let value):
              continuation.resume(returning: .success(value))
            case .failure(let error):
              continuation.resume(returning: .failure(error))
            }
          }
        }
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: UInt64(max(timeoutSeconds, 0) * 1_000_000_000))
        return .timedOut
      }

      let first = await group.next() ?? .timedOut
      group.cancelAll()
      return first
    }
  }
}
