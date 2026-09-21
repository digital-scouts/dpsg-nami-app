import Foundation

/// One turn inside a held multi-turn conversation fixture. Structurally the same fields as a
/// single EvalQuestionFixture minus `id`/`automated_check` (a conversation has one id, not one
/// per turn; every turn in a conversation run is exercised, so `automated_check` doesn't apply
/// per-turn here).
public struct EvalConversationTurnFixture: Decodable, Equatable, Sendable {
  public let question: String
  public let expectedSources: [EvalExpectedSource]
  public let matchMode: String
  public let expectsReject: Bool
  public let note: String?

  enum CodingKeys: String, CodingKey {
    case question, note
    case expectedSources = "expected_sources"
    case matchMode = "match_mode"
    case expectsReject = "expects_reject"
  }
}

/// A sequence of turns run against one held NamiAiAssistant session (startSession -> streamRespond
/// per turn -> endSession), analogous to a real NamiAiChatSession follow-up conversation.
/// selfCorrectionEnabled overrides EvalRunConfig.defaultSelfCorrectionEnabled for this one
/// conversation when non-nil, so a single fixture file can mix default-flag and verifier-pass
/// conversations without a separate CLI invocation.
public struct EvalConversationFixture: Decodable, Equatable, Sendable {
  public let id: String
  public let category: String
  public let selfCorrectionEnabled: Bool?
  public let turns: [EvalConversationTurnFixture]

  enum CodingKeys: String, CodingKey {
    case id, category, turns
    case selfCorrectionEnabled = "self_correction_enabled"
  }
}

public struct EvalConversationsFile: Decodable, Sendable {
  public let evalSetVersion: Int?
  public let conversations: [EvalConversationFixture]

  enum CodingKeys: String, CodingKey {
    case evalSetVersion = "eval_set_version"
    case conversations
  }
}

public enum EvalConversationsLoaderError: Error, Equatable {
  case fileNotFound(URL)
}

public enum EvalConversationsLoader {
  /// Unlike EvalQuestionsLoader, a missing conversations file is a legitimate, non-fatal state
  /// for the CLI (--conversations has a default path that may simply not exist yet) - callers
  /// decide whether to treat EvalConversationsLoaderError.fileNotFound as a warning or an error.
  public static func load(from url: URL) throws -> EvalConversationsFile {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw EvalConversationsLoaderError.fileNotFound(url)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(EvalConversationsFile.self, from: data)
  }
}
