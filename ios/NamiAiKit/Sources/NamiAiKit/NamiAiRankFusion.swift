import Foundation

/// Combines multiple rankings of the same items into one, via Reciprocal Rank Fusion (RRF).
/// Used to merge BM25's lexical ranking with a semantic-embedding ranking
/// (NamiAiRetrievalIndex.topMatchesHybrid, specs/nami-ai-roadmap.md section 3.6 Variante B/D):
/// BM25 scores and cosine similarities live on different, incomparable scales, but ranks are
/// always comparable, so RRF sidesteps having to calibrate/normalize the two signals against
/// each other.
enum NamiAiRankFusion {
  /// `k` is RRF's standard damping constant (60, per Cormack et al. 2009) - large enough that a
  /// single method's very top rank doesn't dominate the fused result outright, small enough that
  /// being ranked highly still matters.
  static func reciprocalRankFusion(rankings: [[Int]], k: Double = 60) -> [Int: Double] {
    var scores: [Int: Double] = [:]
    for ranking in rankings {
      for (offset, itemIndex) in ranking.enumerated() {
        let rank = Double(offset + 1)
        scores[itemIndex, default: 0] += 1 / (k + rank)
      }
    }
    return scores
  }
}
