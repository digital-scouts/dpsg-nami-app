import Foundation

/// Identity of a chunk for grounding-match purposes: (docTitle, sectionNumber) is what the
/// model actually cites in NamiAiGeneratedSourceRef, so matching on the same pair avoids a
/// round-trip through doc_id.
struct NamiAiChunkKey: Hashable {
  let docTitle: String
  let sectionNumber: String
}

/// Collects every chunk NamiAiSearchTool actually delivered during one respond() turn. A
/// single prompt can trigger multiple tool calls (e.g. the model searching again with
/// different terms, possibly concurrently — Tool.call is @concurrent), so this accumulates
/// across all of them rather than keeping only the last call — relevant for the multi-chunk
/// synthesis case found in the 3.3 spike. An actor since Tool requires Sendable and calls may
/// overlap. One instance is created per respond() call, so there's no reset needed between
/// turns.
actor NamiAiRetrievalRecorder {
  private(set) var deliveredKeys: Set<NamiAiChunkKey> = []
  private(set) var deliveredChunkTexts: [String] = []

  func record(_ chunks: [NamiAiChunk]) {
    for chunk in chunks {
      let key = NamiAiChunkKey(docTitle: chunk.docTitle, sectionNumber: chunk.sectionNumber)
      if deliveredKeys.insert(key).inserted {
        deliveredChunkTexts.append(chunk.text)
      }
    }
  }
}
