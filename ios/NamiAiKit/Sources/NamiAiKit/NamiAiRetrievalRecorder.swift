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
/// overlap.
///
/// Since section 3.7, a NamiAiChatSession holds one LanguageModelSession (and therefore one
/// NamiAiSearchTool/recorder instance) across multiple turns instead of building a fresh one
/// per respond() call — so reset() must run at the start of every turn, or deliveredKeys would
/// wrongly accumulate across follow-up questions and let the grounding gate accept sources that
/// were only ever retrieved in an earlier turn.
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

  func reset() {
    deliveredKeys.removeAll()
    deliveredChunkTexts.removeAll()
  }
}
