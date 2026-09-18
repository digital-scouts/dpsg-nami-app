import Foundation

/// A successful NamiAiAssistant response. contextChunks carries the texts of every chunk
/// NamiAiSearchTool actually delivered during this turn (debug/logging use); sources/unclear
/// are the technically-enforced citation result from NamiAiGroundingGate (section 3.6) — sources
/// only ever contains references that were verified against a real tool call.
public struct NamiAiAnswer: Equatable {
  public let text: String
  public let contextChunks: [String]
  public let sources: [NamiAiSourceRef]
  public let unclear: Bool
}
