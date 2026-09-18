import Foundation

/// @Generable enforces only structure, not truth (specs/nami-ai-roadmap.md sections 3.6/3.10) —
/// a model can produce a well-formed NamiAiSourceRef for a section it never actually retrieved.
/// This gate is the runtime check: every cited source must match a chunk NamiAiSearchTool
/// really delivered during this turn, and an answer with no verified source is never presented
/// as a confident answer, no matter what the model itself set `unclear` to.
enum NamiAiGroundingGate {
  static func verify(
    text: String,
    sources: [NamiAiSourceRef],
    unclear: Bool,
    deliveredKeys: Set<NamiAiChunkKey>,
    contextChunks: [String]
  ) -> NamiAiAnswer {
    let verifiedSources = sources.filter {
      deliveredKeys.contains(NamiAiChunkKey(docTitle: $0.docTitle, sectionNumber: $0.sectionNumber))
    }
    return NamiAiAnswer(
      text: text,
      contextChunks: contextChunks,
      sources: verifiedSources,
      unclear: unclear || verifiedSources.isEmpty
    )
  }
}
