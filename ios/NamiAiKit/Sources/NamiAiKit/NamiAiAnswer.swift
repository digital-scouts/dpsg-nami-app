import Foundation

/// A successful NamiAiAssistant response. contextChunks carries a compact "<doc_id>#<section_
/// number>" ref for every chunk NamiAiSearchTool actually delivered during this turn (debug/
/// logging use - the full paragraph text can be looked back up from the corpus by that ref when
/// needed); sources/unclear
/// are the technically-enforced citation result from NamiAiGroundingGate (section 3.6) — sources
/// only ever contains references that were verified against a real tool call. contextTruncated
/// is true exactly for the turn in which a held multi-turn session had to drop older messages
/// after a context-overflow error (section 3.7) — the caller shows a one-time notice for that
/// turn rather than a permanent indicator.
public struct NamiAiAnswer: Equatable {
  public let text: String
  public let contextChunks: [String]
  public let sources: [NamiAiSourceRef]
  public let unclear: Bool
  public let contextTruncated: Bool
}
