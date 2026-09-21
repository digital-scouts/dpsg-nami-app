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
