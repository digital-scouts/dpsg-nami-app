import Foundation
import NamiAiKit

/// One cited source as logged, mirroring nami_ai_debug_log_service.dart's
/// `List<Map<String, String>>` sources shape (docTitle/sectionNumber/docStand keys) so the two
/// logs read the same way side by side.
public struct EvalLoggedSource: Encodable, Equatable, Sendable {
  public let docTitle: String
  public let sectionNumber: String
  public let docStand: String

  public init(_ source: NamiAiSourceRef) {
    self.docTitle = source.docTitle
    self.sectionNumber = source.sectionNumber
    self.docStand = source.docStand
  }
}

/// One logged verifier-pass attempt, field-for-field from NamiAiVerificationAttempt.
public struct EvalLoggedAttempt: Encodable, Equatable, Sendable {
  public let attemptNumber: Int
  public let answerText: String
  public let expectedIntent: String?
  public let intentMatches: Bool?
  public let factsSupportedBySources: Bool?
  public let containsIrrelevantInformation: Bool?
  public let passed: Bool
  public let feedback: String
  public let retryReason: String?

  public init(_ attempt: NamiAiVerificationAttempt) {
    self.attemptNumber = attempt.attemptNumber
    self.answerText = attempt.answerText
    self.expectedIntent = attempt.expectedIntent
    self.intentMatches = attempt.intentMatches
    self.factsSupportedBySources = attempt.factsSupportedBySources
    self.containsIrrelevantInformation = attempt.containsIrrelevantInformation
    self.passed = attempt.passed
    self.feedback = attempt.feedback
    self.retryReason = attempt.retryReason
  }
}

/// One JSONL line, one per turn execution. Field names deliberately mirror
/// lib/services/nami_ai/nami_ai_debug_log_service.dart's schema (timestamp, requestId,
/// sessionId, turnIndex, prompt, outcome, answer, contextChunks, chunkCount, sources, unclear,
/// contextTruncated, verificationFailed, verificationAttempts, errorCode, errorMessage,
/// latencyMs, osVersion) so a reader who knows the app's debug log recognizes this immediately;
/// everything below `category` is eval-only bookkeeping the app log has no use for.
public struct EvalLogEntry: Encodable, Sendable {
  public let timestamp: String
  public let runId: String
  public let requestId: String
  public let fixtureType: String
  public let fixtureId: String
  public let conversationId: String?
  public let repeatIndex: Int
  public let sessionId: String?
  public let turnIndex: Int
  public let prompt: String
  public let outcome: String
  public let answer: String?
  public let contextChunks: [String]
  public let chunkCount: Int
  public let sources: [EvalLoggedSource]
  public let unclear: Bool
  public let contextTruncated: Bool
  public let verificationFailed: Bool
  public let verificationAttempts: [EvalLoggedAttempt]
  public let errorCode: String?
  public let errorMessage: String?
  public let latencyMs: Int
  public let osVersion: String
  public let category: String
  public let expectedSources: [EvalExpectedSource]
  public let matchMode: String
  public let expectsReject: Bool
  public let sourceMatch: Bool
  public let guardrailMatch: Bool
  public let selfCorrectionEnabled: Bool

  public init(
    timestamp: String, runId: String, requestId: String, fixtureType: String, fixtureId: String,
    conversationId: String?, repeatIndex: Int, sessionId: String?, turnIndex: Int, prompt: String,
    outcome: String, answer: String?, contextChunks: [String], sources: [EvalLoggedSource],
    unclear: Bool, contextTruncated: Bool, verificationFailed: Bool,
    verificationAttempts: [EvalLoggedAttempt], errorCode: String?, errorMessage: String?,
    latencyMs: Int, osVersion: String, category: String, expectedSources: [EvalExpectedSource],
    matchMode: String, expectsReject: Bool, sourceMatch: Bool, guardrailMatch: Bool,
    selfCorrectionEnabled: Bool
  ) {
    self.timestamp = timestamp
    self.runId = runId
    self.requestId = requestId
    self.fixtureType = fixtureType
    self.fixtureId = fixtureId
    self.conversationId = conversationId
    self.repeatIndex = repeatIndex
    self.sessionId = sessionId
    self.turnIndex = turnIndex
    self.prompt = prompt
    self.outcome = outcome
    self.answer = answer
    self.contextChunks = contextChunks
    self.chunkCount = contextChunks.count
    self.sources = sources
    self.unclear = unclear
    self.contextTruncated = contextTruncated
    self.verificationFailed = verificationFailed
    self.verificationAttempts = verificationAttempts
    self.errorCode = errorCode
    self.errorMessage = errorMessage
    self.latencyMs = latencyMs
    self.osVersion = osVersion
    self.category = category
    self.expectedSources = expectedSources
    self.matchMode = matchMode
    self.expectsReject = expectsReject
    self.sourceMatch = sourceMatch
    self.guardrailMatch = guardrailMatch
    self.selfCorrectionEnabled = selfCorrectionEnabled
  }

  private enum CodingKeys: String, CodingKey {
    case timestamp, runId, requestId, fixtureType, fixtureId, conversationId, repeatIndex,
      sessionId, turnIndex, prompt, outcome, answer, contextChunks, chunkCount, sources, unclear,
      contextTruncated, verificationFailed, verificationAttempts, errorCode, errorMessage,
      latencyMs, osVersion, category, expectedSources, matchMode, expectsReject, sourceMatch,
      guardrailMatch, selfCorrectionEnabled
  }

  /// Hand-written instead of relying on synthesis: the auto-synthesized Encodable conformance
  /// calls encodeIfPresent for Optional properties, which OMITS the key entirely for nil rather
  /// than writing JSON null - that would silently drop conversationId/errorCode/errorMessage
  /// from single-turn/successful entries, breaking the "field always present, sometimes null"
  /// schema this type documents (and that chat_ai/eval/report_eval_run.py relies on reading
  /// consistently). encode(_:forKey:) on an Optional, unlike encodeIfPresent, always keeps the
  /// key and encodes null for .none.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(runId, forKey: .runId)
    try container.encode(requestId, forKey: .requestId)
    try container.encode(fixtureType, forKey: .fixtureType)
    try container.encode(fixtureId, forKey: .fixtureId)
    try container.encode(conversationId, forKey: .conversationId)
    try container.encode(repeatIndex, forKey: .repeatIndex)
    try container.encode(sessionId, forKey: .sessionId)
    try container.encode(turnIndex, forKey: .turnIndex)
    try container.encode(prompt, forKey: .prompt)
    try container.encode(outcome, forKey: .outcome)
    try container.encode(answer, forKey: .answer)
    try container.encode(contextChunks, forKey: .contextChunks)
    try container.encode(chunkCount, forKey: .chunkCount)
    try container.encode(sources, forKey: .sources)
    try container.encode(unclear, forKey: .unclear)
    try container.encode(contextTruncated, forKey: .contextTruncated)
    try container.encode(verificationFailed, forKey: .verificationFailed)
    try container.encode(verificationAttempts, forKey: .verificationAttempts)
    try container.encode(errorCode, forKey: .errorCode)
    try container.encode(errorMessage, forKey: .errorMessage)
    try container.encode(latencyMs, forKey: .latencyMs)
    try container.encode(osVersion, forKey: .osVersion)
    try container.encode(category, forKey: .category)
    try container.encode(expectedSources, forKey: .expectedSources)
    try container.encode(matchMode, forKey: .matchMode)
    try container.encode(expectsReject, forKey: .expectsReject)
    try container.encode(sourceMatch, forKey: .sourceMatch)
    try container.encode(guardrailMatch, forKey: .guardrailMatch)
    try container.encode(selfCorrectionEnabled, forKey: .selfCorrectionEnabled)
  }
}

public enum EvalLogWriter {
  /// Appends one line (compact JSON + "\n") to fileURL, creating the file/parent directory on
  /// first write. Writes are flushed synchronously per call (not buffered across the whole run)
  /// so progress survives a crash or Ctrl-C partway through a long --repeat run.
  public static func append(_ entry: EvalLogEntry, to fileURL: URL) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(entry)
    var line = data
    line.append(0x0A)

    let directory = fileURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }
    let handle = try FileHandle(forWritingTo: fileURL)
    defer { try? handle.close() }
    _ = try handle.seekToEnd()
    try handle.write(contentsOf: line)
  }
}
