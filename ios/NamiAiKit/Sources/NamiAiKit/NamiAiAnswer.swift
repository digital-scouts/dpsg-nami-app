import Foundation

/// A successful NamiAiAssistant response. contextChunks carries a compact "<doc_id>#<section_
/// number>" ref for every chunk NamiAiSearchTool actually delivered during this turn (debug/
/// logging use - the full paragraph text can be looked back up from the corpus by that ref when
/// needed); sources/unclear
/// are the technically-enforced citation result from NamiAiGroundingGate (section 3.6) — sources
/// only ever contains references that were verified against a real tool call. contextTruncated
/// is true exactly for the turn in which a held multi-turn session had to drop older messages
/// after a context-overflow error (section 3.7) — the caller shows a one-time notice for that
/// turn rather than a permanent indicator. verificationFailed/verificationAttempts surface the
/// verifier-pass self-correction result (section 3.12) — kept separate from `unclear`
/// (grounding-gate semantics: "no verifiable source") since a verifier failure such as "contains
/// irrelevant information" means something different and callers should be able to tell them
/// apart.
public struct NamiAiAnswer: Equatable {
  public let text: String
  public let contextChunks: [String]
  public let sources: [NamiAiSourceRef]
  public let unclear: Bool
  public let contextTruncated: Bool
  /// true when even the last (third) attempt after 2 retries still failed the verifier pass.
  public let verificationFailed: Bool
  /// Debug/logging use, analogous to contextChunks - not meant for user-facing UI.
  public let verificationAttempts: [NamiAiVerificationAttempt]
}

extension NamiAiAnswer {
  func withVerification(failed: Bool, attempts: [NamiAiVerificationAttempt]) -> NamiAiAnswer {
    NamiAiAnswer(
      text: text, contextChunks: contextChunks, sources: sources, unclear: unclear,
      contextTruncated: contextTruncated, verificationFailed: failed,
      verificationAttempts: attempts)
  }
}
