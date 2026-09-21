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

/// Resumes a single CheckedContinuation exactly once, whichever of several concurrent sources
/// wins first - a later call is silently ignored instead of triggering Swift's "resumed more
/// than once" trap. Isolating this in an actor makes the race between the operation's completion
/// and the timeout race-free without needing a lock.
private actor EvalContinuationResumer<T: Sendable> {
  private var continuation: CheckedContinuation<EvalAsyncOutcome<T>, Never>?

  init(continuation: CheckedContinuation<EvalAsyncOutcome<T>, Never>) {
    self.continuation = continuation
  }

  func resume(with outcome: EvalAsyncOutcome<T>) {
    guard let continuation else { return }
    self.continuation = nil
    continuation.resume(returning: outcome)
  }
}

/// Every NamiAiAssistant entry point (startSession/streamRespond/endSession) is completion-
/// based, since it's built for a UI event loop, not a script. This is the one generic adapter
/// the CLI needs to turn those into `async` calls with a bounded wait - a model call can
/// pathologically hang (see chat_ai/eval/README.md "Bekannte Grenzen" on non-determinism), and a
/// batch run over dozens of fixtures must not be able to hang forever on a single one.
public enum EvalAsyncBridge {
  /// Races `operation`'s completion against a `timeoutSeconds` sleep; whichever finishes first
  /// wins. Deliberately does NOT use withTaskGroup/withCheckedContinuation around `operation`
  /// itself: if `operation` never calls back (the exact case --timeout-seconds exists for), a
  /// continuation created to await it would be a genuinely unresumable child task, and
  /// structured concurrency requires the enclosing scope to await every child task before
  /// returning - so the whole function would hang forever waiting for a continuation that can,
  /// by construction, never resume (this is what "SWIFT TASK CONTINUATION MISUSE: leaked its
  /// continuation" means, and it's not fixable by cancellation - cancelling a task never force-
  /// resumes a suspended continuation). Instead, there is exactly ONE continuation - the outer
  /// one - and it's resumed exactly once by whichever of two independent, unstructured Tasks
  /// (the completion forwarder, the timeout sleeper) gets there first, guarded by
  /// EvalContinuationResumer. `operation`'s completion, if it does arrive after a timeout, just
  /// finds the continuation already consumed and is a no-op.
  public static func awaiting<T: Sendable>(
    timeoutSeconds: Double,
    _ operation: @escaping (@escaping (Result<T, NamiAiError>) -> Void) -> Void
  ) async -> EvalAsyncOutcome<T> {
    await withCheckedContinuation {
      (continuation: CheckedContinuation<EvalAsyncOutcome<T>, Never>) in
      let resumer = EvalContinuationResumer(continuation: continuation)

      operation { result in
        Task {
          switch result {
          case .success(let value):
            await resumer.resume(with: .success(value))
          case .failure(let error):
            await resumer.resume(with: .failure(error))
          }
        }
      }

      Task {
        try? await Task.sleep(nanoseconds: UInt64(max(timeoutSeconds, 0) * 1_000_000_000))
        await resumer.resume(with: .timedOut)
      }
    }
  }
}
