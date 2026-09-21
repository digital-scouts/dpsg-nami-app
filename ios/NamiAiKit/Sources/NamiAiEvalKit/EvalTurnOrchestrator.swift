import Foundation
import NamiAiKit

public struct EvalRunConfig: Sendable {
  public let runId: String
  public let repeatCount: Int
  public let defaultSelfCorrectionEnabled: Bool

  public init(runId: String, repeatCount: Int, defaultSelfCorrectionEnabled: Bool) {
    self.runId = runId
    self.repeatCount = repeatCount
    self.defaultSelfCorrectionEnabled = defaultSelfCorrectionEnabled
  }
}

/// Abstraction over the three NamiAiAssistant calls that make up one held session, so
/// EvalTurnOrchestrator's control flow (repeat counting, turn indexing, error handling, log
/// building) is testable with a fake driver - no real NamiAiKit/model call needed. The real
/// implementation (NamiAiEvalCLI) wraps NamiAiAssistant's completion-based calls via
/// EvalAsyncBridge.awaiting, including the CLI's --timeout-seconds.
public protocol EvalSessionDriving: Sendable {
  func startSession(selfCorrectionEnabled: Bool) async -> EvalAsyncOutcome<String>
  func streamRespond(sessionId: String, to prompt: String) async -> EvalAsyncOutcome<NamiAiAnswer>
  func endSession(sessionId: String) async
}

public enum EvalTurnOrchestrator {
  /// Runs one single-turn question `config.repeatCount` times, each time as its own fresh
  /// session (startSession -> exactly one streamRespond -> endSession) - never the one-shot
  /// NamiAiAssistant.respond(to:), so the exercised path matches the chat UI's, which always
  /// goes through a held session (see plan: "Logik vollständig identisch zur UI").
  public static func runQuestion(
    _ question: EvalQuestionFixture,
    driver: EvalSessionDriving,
    titleIndex: EvalCorpusTitleIndex,
    config: EvalRunConfig
  ) async -> [EvalLogEntry] {
    var entries: [EvalLogEntry] = []
    for repeatIndex in 0..<config.repeatCount {
      let entry = await runSingleTurnRepeat(
        question, driver: driver, titleIndex: titleIndex, config: config,
        repeatIndex: repeatIndex)
      entries.append(entry)
    }
    return entries
  }

  private static func runSingleTurnRepeat(
    _ question: EvalQuestionFixture,
    driver: EvalSessionDriving,
    titleIndex: EvalCorpusTitleIndex,
    config: EvalRunConfig,
    repeatIndex: Int
  ) async -> EvalLogEntry {
    let startOutcome = await driver.startSession(
      selfCorrectionEnabled: config.defaultSelfCorrectionEnabled)
    guard case .success(let sessionId) = startOutcome else {
      return startFailureEntry(
        fixtureType: "question", fixtureId: question.id, conversationId: nil,
        repeatIndex: repeatIndex, turnIndex: 1, prompt: question.question, outcome: startOutcome,
        category: question.category, expectedSources: question.expectedSources,
        matchMode: question.matchMode, expectsReject: question.expectsReject,
        selfCorrectionEnabled: config.defaultSelfCorrectionEnabled, config: config)
    }

    let started = Date()
    let respondOutcome = await driver.streamRespond(sessionId: sessionId, to: question.question)
    let latencyMs = Int(Date().timeIntervalSince(started) * 1000)
    await driver.endSession(sessionId: sessionId)

    return buildEntry(
      fixtureType: "question", fixtureId: question.id, conversationId: nil,
      repeatIndex: repeatIndex, sessionId: sessionId, turnIndex: 1, prompt: question.question,
      outcome: respondOutcome, latencyMs: latencyMs, category: question.category,
      expectedSources: question.expectedSources, matchMode: question.matchMode,
      expectsReject: question.expectsReject, titleIndex: titleIndex,
      selfCorrectionEnabled: config.defaultSelfCorrectionEnabled, config: config)
  }

  /// Runs one multi-turn conversation `config.repeatCount` times, each time as ONE held session
  /// across all turns (startSession -> streamRespond per turn in sequence -> endSession),
  /// analogous to a real NamiAiChatSession follow-up flow. Stops the conversation early (but
  /// still ends the session) on the first turn that doesn't succeed, since later turns rely on
  /// the session's accumulated context and would otherwise fail for an uninformative reason.
  public static func runConversation(
    _ conversation: EvalConversationFixture,
    driver: EvalSessionDriving,
    titleIndex: EvalCorpusTitleIndex,
    config: EvalRunConfig
  ) async -> [EvalLogEntry] {
    let selfCorrectionEnabled =
      conversation.selfCorrectionEnabled ?? config.defaultSelfCorrectionEnabled
    var entries: [EvalLogEntry] = []
    for repeatIndex in 0..<config.repeatCount {
      entries.append(
        contentsOf: await runConversationRepeat(
          conversation, driver: driver, titleIndex: titleIndex, config: config,
          repeatIndex: repeatIndex, selfCorrectionEnabled: selfCorrectionEnabled))
    }
    return entries
  }

  private static func runConversationRepeat(
    _ conversation: EvalConversationFixture,
    driver: EvalSessionDriving,
    titleIndex: EvalCorpusTitleIndex,
    config: EvalRunConfig,
    repeatIndex: Int,
    selfCorrectionEnabled: Bool
  ) async -> [EvalLogEntry] {
    guard let firstTurn = conversation.turns.first else { return [] }

    let startOutcome = await driver.startSession(selfCorrectionEnabled: selfCorrectionEnabled)
    guard case .success(let sessionId) = startOutcome else {
      return [
        startFailureEntry(
          fixtureType: "conversation", fixtureId: conversation.id,
          conversationId: conversation.id, repeatIndex: repeatIndex, turnIndex: 1,
          prompt: firstTurn.question, outcome: startOutcome, category: conversation.category,
          expectedSources: firstTurn.expectedSources, matchMode: firstTurn.matchMode,
          expectsReject: firstTurn.expectsReject, selfCorrectionEnabled: selfCorrectionEnabled,
          config: config)
      ]
    }

    var entries: [EvalLogEntry] = []
    for (offset, turn) in conversation.turns.enumerated() {
      let turnIndex = offset + 1
      let started = Date()
      let respondOutcome = await driver.streamRespond(sessionId: sessionId, to: turn.question)
      let latencyMs = Int(Date().timeIntervalSince(started) * 1000)

      entries.append(
        buildEntry(
          fixtureType: "conversation", fixtureId: conversation.id,
          conversationId: conversation.id, repeatIndex: repeatIndex, sessionId: sessionId,
          turnIndex: turnIndex, prompt: turn.question, outcome: respondOutcome,
          latencyMs: latencyMs, category: conversation.category,
          expectedSources: turn.expectedSources, matchMode: turn.matchMode,
          expectsReject: turn.expectsReject, titleIndex: titleIndex,
          selfCorrectionEnabled: selfCorrectionEnabled, config: config))

      if case .success = respondOutcome {
        continue
      }
      break
    }
    await driver.endSession(sessionId: sessionId)
    return entries
  }

  // MARK: - Log entry construction

  private static func buildEntry(
    fixtureType: String, fixtureId: String, conversationId: String?, repeatIndex: Int,
    sessionId: String, turnIndex: Int, prompt: String, outcome: EvalAsyncOutcome<NamiAiAnswer>,
    latencyMs: Int, category: String, expectedSources: [EvalExpectedSource], matchMode: String,
    expectsReject: Bool, titleIndex: EvalCorpusTitleIndex, selfCorrectionEnabled: Bool,
    config: EvalRunConfig
  ) -> EvalLogEntry {
    switch outcome {
    case .success(let answer):
      let sourceMatchResult = EvalMatcher.matchSources(
        citedSources: answer.sources, expected: expectedSources, matchMode: matchMode,
        titleIndex: titleIndex)
      let guardrailMatch = EvalMatcher.matchGuardrail(
        expectsReject: expectsReject, answerUnclear: answer.unclear)
      return EvalLogEntry(
        timestamp: isoTimestamp(), runId: config.runId, requestId: UUID().uuidString,
        fixtureType: fixtureType, fixtureId: fixtureId, conversationId: conversationId,
        repeatIndex: repeatIndex, sessionId: sessionId, turnIndex: turnIndex, prompt: prompt,
        outcome: "success", answer: answer.text, contextChunks: answer.contextChunks,
        sources: answer.sources.map(EvalLoggedSource.init), unclear: answer.unclear,
        contextTruncated: answer.contextTruncated, verificationFailed: answer.verificationFailed,
        verificationAttempts: answer.verificationAttempts.map(EvalLoggedAttempt.init),
        errorCode: nil, errorMessage: nil, latencyMs: latencyMs, osVersion: osVersionString(),
        category: category, expectedSources: expectedSources, matchMode: matchMode,
        expectsReject: expectsReject, sourceMatch: sourceMatchResult.ok,
        guardrailMatch: guardrailMatch, selfCorrectionEnabled: selfCorrectionEnabled)
    case .failure(let error):
      return EvalLogEntry(
        timestamp: isoTimestamp(), runId: config.runId, requestId: UUID().uuidString,
        fixtureType: fixtureType, fixtureId: fixtureId, conversationId: conversationId,
        repeatIndex: repeatIndex, sessionId: sessionId, turnIndex: turnIndex, prompt: prompt,
        outcome: "error", answer: nil, contextChunks: [], sources: [], unclear: false,
        contextTruncated: false, verificationFailed: false, verificationAttempts: [],
        errorCode: error.flutterErrorCode, errorMessage: error.userMessage, latencyMs: latencyMs,
        osVersion: osVersionString(), category: category, expectedSources: expectedSources,
        matchMode: matchMode, expectsReject: expectsReject, sourceMatch: false,
        guardrailMatch: false, selfCorrectionEnabled: selfCorrectionEnabled)
    case .timedOut:
      return EvalLogEntry(
        timestamp: isoTimestamp(), runId: config.runId, requestId: UUID().uuidString,
        fixtureType: fixtureType, fixtureId: fixtureId, conversationId: conversationId,
        repeatIndex: repeatIndex, sessionId: sessionId, turnIndex: turnIndex, prompt: prompt,
        outcome: "timeout", answer: nil, contextChunks: [], sources: [], unclear: false,
        contextTruncated: false, verificationFailed: false, verificationAttempts: [],
        errorCode: "eval_timeout", errorMessage: "CLI-Timeout beim Warten auf die Antwort.",
        latencyMs: latencyMs, osVersion: osVersionString(), category: category,
        expectedSources: expectedSources, matchMode: matchMode, expectsReject: expectsReject,
        sourceMatch: false, guardrailMatch: false, selfCorrectionEnabled: selfCorrectionEnabled)
    }
  }

  /// Log entry for a turn that never ran because startSession itself didn't succeed - no
  /// sessionId, no answer, latency isn't meaningful (nothing was awaited beyond the failed
  /// start) so it's logged as 0.
  private static func startFailureEntry(
    fixtureType: String, fixtureId: String, conversationId: String?, repeatIndex: Int,
    turnIndex: Int, prompt: String, outcome: EvalAsyncOutcome<String>, category: String,
    expectedSources: [EvalExpectedSource], matchMode: String, expectsReject: Bool,
    selfCorrectionEnabled: Bool, config: EvalRunConfig
  ) -> EvalLogEntry {
    let outcomeString: String
    let errorCode: String?
    let errorMessage: String?
    switch outcome {
    case .success:
      // Unreachable: callers only build this entry once startSession did NOT succeed.
      outcomeString = "error"
      errorCode = nil
      errorMessage = nil
    case .failure(let error):
      outcomeString = "error"
      errorCode = error.flutterErrorCode
      errorMessage = error.userMessage
    case .timedOut:
      outcomeString = "timeout"
      errorCode = "eval_timeout"
      errorMessage = "CLI-Timeout beim Starten der Session."
    }
    return EvalLogEntry(
      timestamp: isoTimestamp(), runId: config.runId, requestId: UUID().uuidString,
      fixtureType: fixtureType, fixtureId: fixtureId, conversationId: conversationId,
      repeatIndex: repeatIndex, sessionId: nil, turnIndex: turnIndex, prompt: prompt,
      outcome: outcomeString, answer: nil, contextChunks: [], sources: [], unclear: false,
      contextTruncated: false, verificationFailed: false, verificationAttempts: [],
      errorCode: errorCode, errorMessage: errorMessage, latencyMs: 0, osVersion: osVersionString(),
      category: category, expectedSources: expectedSources, matchMode: matchMode,
      expectsReject: expectsReject, sourceMatch: false, guardrailMatch: false,
      selfCorrectionEnabled: selfCorrectionEnabled)
  }

  private static func isoTimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
  }

  private static func osVersionString() -> String {
    ProcessInfo.processInfo.operatingSystemVersionString
  }
}
