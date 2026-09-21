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
    /// Feature flag for the verifier-pass self-correction loop (specs/nami-ai-roadmap.md section
    /// 3.12), set once at session start from NamiAiEnv.selfCorrectionEnabled on the Dart side.
    /// When false, respond()/streamRespond() call NamiAiResponder.runTurn directly - today's
    /// behavior, no verifier pass, no retries - so the feature can be turned off without a
    /// native rebuild while its latency/retry-rate impact is still being measured.
    private let selfCorrectionEnabled: Bool

    init(id: String, selfCorrectionEnabled: Bool) {
      self.id = id
      self.selfCorrectionEnabled = selfCorrectionEnabled
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
        let result = await performWithOverflowRetry { contextTruncated in
          if self.selfCorrectionEnabled {
            return try await self.runTurnWithSelfCorrection(
              prompt: prompt, contextTruncated: contextTruncated)
          }
          return try await NamiAiResponder.runTurn(
            session: self.session, recorder: self.recorder, prompt: prompt,
            contextTruncated: contextTruncated)
        }
        completion(result)
      }
    }

    /// Streaming counterpart of respond() (specs/nami-ai-roadmap.md section 3.7:
    /// session.streamResponse via a new EventChannel instead of waiting for the full answer).
    /// onPartial delivers only the growing answer text — sources/unclear (the grounding-gate
    /// verified result) are only meaningful once the whole turn, including every tool call, has
    /// finished, so they're only ever part of the final NamiAiAnswer passed to completion.
    /// onRevising fires once whenever the verifier pass (section 3.12) rejects an attempt and a
    /// retry starts - the caller should replace the just-streamed (rejected) partial text with a
    /// brief "wird überprüft" state rather than silently overwriting already-visible text with a
    /// new stream, since that would look like a bug rather than a deliberate correction.
    func streamRespond(
      to prompt: String,
      onPartial: @escaping (String) -> Void,
      onRevising: @escaping () -> Void,
      completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
    ) {
      guard NamiAiCorpus.index() != nil else {
        completion(.failure(.contextMissing))
        return
      }
      Task {
        let result = await performWithOverflowRetry { contextTruncated in
          if self.selfCorrectionEnabled {
            return try await self.streamTurnWithSelfCorrection(
              prompt: prompt, contextTruncated: contextTruncated, onPartial: onPartial,
              onRevising: onRevising)
          }
          return try await self.runStreamingTurn(
            prompt: prompt, contextTruncated: contextTruncated, onPartial: onPartial)
        }
        completion(result)
      }
    }

    /// Rolls session+recorder back to the state right before this user turn before every retry
    /// (specs/nami-ai-roadmap.md section 3.12), so the finished transcript always ends up with
    /// exactly one new turn - whichever attempt actually ran last - never a discarded
    /// intermediate attempt or a separate correction prompt. Reuses the same
    /// LanguageModelSession(tools:transcript:) rebuild mechanism rebuildAfterOverflow() already
    /// uses for sliding-window truncation, rather than introducing a second, unproven way to
    /// manipulate the transcript.
    private func runTurnWithSelfCorrection(
      prompt: String, contextTruncated: Bool
    ) async throws -> NamiAiAnswer {
      let baselineEntries = Array(session.transcript)
      let (answer, verificationFailed, attempts) = try await NamiAiResponder.performSelfCorrection(
        question: prompt
      ) { attemptPrompt, attemptNumber in
        if attemptNumber > 1 {
          self.rollBackToBaseline(baselineEntries)
        }
        let answer = try await NamiAiResponder.runTurn(
          session: self.session, recorder: self.recorder, prompt: attemptPrompt,
          contextTruncated: contextTruncated)
        return (answer, await self.recorder.deliveredChunks)
      }
      return answer.withVerification(failed: verificationFailed, attempts: attempts)
    }

    /// Streaming counterpart of runTurnWithSelfCorrection() - same rollback-per-retry policy,
    /// but forwards partial text per attempt and signals onRevising before a retry replaces
    /// already-streamed (rejected) text.
    private func streamTurnWithSelfCorrection(
      prompt: String, contextTruncated: Bool,
      onPartial: @escaping (String) -> Void, onRevising: @escaping () -> Void
    ) async throws -> NamiAiAnswer {
      let baselineEntries = Array(session.transcript)
      let (answer, verificationFailed, attempts) = try await NamiAiResponder.performSelfCorrection(
        question: prompt
      ) { attemptPrompt, attemptNumber in
        if attemptNumber > 1 {
          onRevising()
          self.rollBackToBaseline(baselineEntries)
        }
        let answer = try await self.runStreamingTurn(
          prompt: attemptPrompt, contextTruncated: contextTruncated, onPartial: onPartial)
        return (answer, await self.recorder.deliveredChunks)
      }
      return answer.withVerification(failed: verificationFailed, attempts: attempts)
    }

    /// Rebuilds session+recorder from a previously captured transcript snapshot, discarding
    /// whatever the just-rejected attempt appended - the same primitive rebuildAfterOverflow()
    /// uses, applied here to a plain retry instead of a context-overflow error.
    private func rollBackToBaseline(_ baselineEntries: [Transcript.Entry]) {
      let newRecorder = NamiAiRetrievalRecorder()
      session = LanguageModelSession(
        tools: [NamiAiSearchTool(recorder: newRecorder)],
        transcript: Transcript(entries: baselineEntries))
      recorder = newRecorder
    }

    /// Shared retry orchestration for both respond() and streamRespond(): resets the recorder,
    /// runs the turn once, and on a context-overflow error rebuilds the session (sliding-window
    /// truncation) and retries exactly once before giving up — truncating repeatedly risks
    /// dropping the current prompt itself.
    private func performWithOverflowRetry(
      runOnce: (Bool) async throws -> NamiAiAnswer
    ) async -> Result<NamiAiAnswer, NamiAiError> {
      await recorder.reset()
      do {
        let answer = try await runOnce(false)
        return .success(answer)
      } catch let error as LanguageModelSession.GenerationError where Self.isContextOverflow(error)
      {
        rebuildAfterOverflow()
        await recorder.reset()
        do {
          let answer = try await runOnce(true)
          return .success(answer)
        } catch {
          return .failure(NamiAiResponder.mapGenerationError(error))
        }
      } catch {
        return .failure(NamiAiResponder.mapGenerationError(error))
      }
    }

    /// Runs one streaming turn, forwarding each growing answer-text prefix to onPartial, and
    /// wraps the final snapshot through NamiAiGroundingGate exactly like the non-streaming path.
    private func runStreamingTurn(
      prompt: String,
      contextTruncated: Bool,
      onPartial: @escaping (String) -> Void
    ) async throws -> NamiAiAnswer {
      let stream = session.streamResponse(to: prompt, generating: NamiAiGeneratedAnswer.self)
      var lastSnapshotContent: NamiAiGeneratedAnswer.PartiallyGenerated?
      var lastAnswerText = ""
      for try await snapshot in stream {
        lastSnapshotContent = snapshot.content
        if let partialAnswer = snapshot.content.answer, partialAnswer != lastAnswerText {
          lastAnswerText = partialAnswer
          onPartial(partialAnswer)
        }
      }
      let sources =
        lastSnapshotContent?.sources?.compactMap { partial -> NamiAiSourceRef? in
          guard let docTitle = partial.docTitle, let sectionNumber = partial.sectionNumber,
            let docStand = partial.docStand
          else {
            return nil
          }
          return NamiAiSourceRef(
            docTitle: docTitle, sectionNumber: sectionNumber, docStand: docStand)
        } ?? []
      return NamiAiGroundingGate.verify(
        text: lastSnapshotContent?.answer ?? lastAnswerText,
        sources: sources,
        // nil here means the model never finished declaring unclear - fail safe towards true
        // rather than assuming a confident answer that was never actually confirmed complete.
        unclear: lastSnapshotContent?.unclear ?? true,
        deliveredKeys: await recorder.deliveredKeys,
        contextChunks: await recorder.deliveredChunkRefs,
        contextTruncated: contextTruncated
      )
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
      rollBackToBaseline(keptEntries)
    }
  }
#endif
