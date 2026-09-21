import Foundation

/// Abstraction over "how similar is this query to each chunk" via a dense embedding model,
/// independent of any specific embedding technology. Lets the fusion logic in
/// NamiAiRetrievalIndex.topMatchesHybrid be unit-tested with a fake (NamiAiRetrievalTests.swift),
/// since the real NLContextualEmbedding-backed implementation
/// (NamiAiContextualEmbeddingScorer) needs on-device model assets that are never present in
/// CI/the simulator (specs/nami-ai-roadmap.md section 3.6, Variante B).
protocol NamiAiSemanticScorer: Sendable {
  /// Returns a similarity score for `query` against every chunk in `chunks`, same order/count
  /// as `chunks` (higher is more similar) - or nil if the embedding model/assets aren't
  /// available right now, which callers must treat as "fall back to BM25 only", never as an
  /// error to surface to the user.
  func similarityScores(for query: String, against chunks: [NamiAiChunk]) async -> [Double]?
}
