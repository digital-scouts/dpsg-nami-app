import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Holds one LanguageModelSession alive across multiple turns instead of rebuilding it per
  /// question (specs/nami-ai-roadmap.md section 3.7: "eine LanguageModelSession pro
  /// Chat-Session nativ am Leben halten"). NamiAiRetrievalRecorder must be reset at the start of
  /// every turn even though the session and its bound NamiAiSearchTool stay the same object
  /// across turns — otherwise deliveredKeys would wrongly accumulate across follow-up questions
  /// and let the grounding gate accept sources that were only ever retrieved earlier.
  @available(iOS 26.0, macOS 26.0, *)
  final class NamiAiChatSession {
    /// Turns kept when rebuilding the session after a context-overflow error.
    private static let maxRetainedTurnsOnOverflow = 2

    let id: String
    private var session: LanguageModelSession
    private var recorder: NamiAiRetrievalRecorder

    init(id: String) {
      self.id = id
      (session, recorder) = NamiAiResponder.makeSession()
    }

    func respond(
      to prompt: String,
      completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
    ) {
      guard NamiAiCorpus.index() != nil else {
        completion(.failure(.contextMissing))
        return
      }

      Task {
        await recorder.reset()
        do {
          let answer = try await NamiAiResponder.runTurn(
            session: session, recorder: recorder, prompt: prompt, contextTruncated: false)
          completion(.success(answer))
        } catch let error as LanguageModelSession.GenerationError
          where Self.isContextOverflow(error)
        {
          rebuildAfterOverflow()
          await recorder.reset()
          do {
            let answer = try await NamiAiResponder.runTurn(
              session: session, recorder: recorder, prompt: prompt, contextTruncated: true)
            completion(.success(answer))
          } catch {
            // Truncating once and retrying still overflowed (or hit a different error) — give up
            // rather than truncating repeatedly, which risks dropping the current prompt itself.
            completion(.failure(NamiAiResponder.mapGenerationError(error)))
          }
        } catch {
          completion(.failure(NamiAiResponder.mapGenerationError(error)))
        }
      }
    }

    private static func isContextOverflow(_ error: LanguageModelSession.GenerationError) -> Bool {
      if case .exceededContextWindowSize = error {
        return true
      }
      return false
    }

    /// Drops older turns and rebuilds the session against the trimmed transcript (sliding-window
    /// truncation, specs/nami-ai-roadmap.md section 3.7). Reading session.transcript and
    /// LanguageModelSession(tools:transcript:) are both available from iOS 26 for the
    /// SystemLanguageModel-default overload used here — verified against the installed
    /// FoundationModels SDK (not just documentation), since GenerationError's exact behavior
    /// here isn't otherwise exercised by this package's tests.
    private func rebuildAfterOverflow() {
      let keptEntries = NamiAiSlidingWindow.truncated(
        Array(session.transcript),
        keepLastTurns: Self.maxRetainedTurnsOnOverflow,
        isInstructions: { if case .instructions = $0 { true } else { false } },
        isTurnBoundary: { if case .response = $0 { true } else { false } }
      )
      let newRecorder = NamiAiRetrievalRecorder()
      session = LanguageModelSession(
        tools: [NamiAiSearchTool(recorder: newRecorder)],
        transcript: Transcript(entries: keptEntries)
      )
      recorder = newRecorder
    }
  }
#endif
