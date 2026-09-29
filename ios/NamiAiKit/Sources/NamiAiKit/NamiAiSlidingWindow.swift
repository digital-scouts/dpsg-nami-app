import Foundation

/// Pure windowing algorithm for truncating a conversation transcript after a context-overflow
/// error (specs/nami-ai-roadmap.md section 3.7: "Sliding-Window-Truncation: letzte 1-2 Turns
/// behalten, neue Session mit gleichem Systemprompt"). Deliberately generic over the entry type
/// and classified via closures instead of depending on FoundationModels.Transcript.Entry
/// directly, so the windowing logic itself stays testable without importing FoundationModels or
/// touching a device/model. NamiAiChatSession supplies the real Transcript.Entry classification.
enum NamiAiSlidingWindow {
  /// A "turn" ends at each entry classified as a turn boundary (a model response). Keeps every
  /// entry classified as instructions (system prompt, kept once regardless of position) plus
  /// everything from the start of the (keepLastTurns + 1)-th-to-last turn boundary onward. If
  /// there aren't more than keepLastTurns turns yet, returns entries unchanged.
  static func truncated<Entry>(
    _ entries: [Entry],
    keepLastTurns: Int,
    isInstructions: (Entry) -> Bool,
    isTurnBoundary: (Entry) -> Bool
  ) -> [Entry] {
    let boundaryIndices = entries.indices.filter { isTurnBoundary(entries[$0]) }
    guard boundaryIndices.count > keepLastTurns else { return entries }

    let cutoffBoundaryIndex = boundaryIndices[boundaryIndices.count - keepLastTurns - 1]
    let instructionEntries = entries.filter(isInstructions)
    let keptTail = entries[(cutoffBoundaryIndex + 1)...]
    return instructionEntries + keptTail
  }
}
