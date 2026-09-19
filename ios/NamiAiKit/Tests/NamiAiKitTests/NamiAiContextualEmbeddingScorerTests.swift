import XCTest

@testable import NamiAiKit

/// Only the pure, model-independent parts of NamiAiContextualEmbeddingScorer are testable here
/// (cosineSimilarity) - everything else needs real on-device NLContextualEmbedding model assets
/// that are never present in CI/the simulator (see the type's own doc comment). End-to-end
/// behavior (does it actually improve retrieval quality) is a manual-device verification item,
/// same class of limitation as the rest of this package's FoundationModels-dependent code.
@available(iOS 17.0, macOS 14.0, *)
final class NamiAiContextualEmbeddingScorerTests: XCTestCase {
  func testCosineSimilarityOfIdenticalVectorsIsOne() {
    let similarity = NamiAiContextualEmbeddingScorer.cosineSimilarity([1, 2, 3], [1, 2, 3])
    XCTAssertEqual(similarity, 1.0, accuracy: 0.0001)
  }

  func testCosineSimilarityOfOrthogonalVectorsIsZero() {
    let similarity = NamiAiContextualEmbeddingScorer.cosineSimilarity([1, 0], [0, 1])
    XCTAssertEqual(similarity, 0.0, accuracy: 0.0001)
  }

  func testCosineSimilarityOfOppositeVectorsIsMinusOne() {
    let similarity = NamiAiContextualEmbeddingScorer.cosineSimilarity([1, 0], [-1, 0])
    XCTAssertEqual(similarity, -1.0, accuracy: 0.0001)
  }

  func testCosineSimilarityIsScaleInvariant() {
    let similarity = NamiAiContextualEmbeddingScorer.cosineSimilarity([1, 2, 3], [2, 4, 6])
    XCTAssertEqual(similarity, 1.0, accuracy: 0.0001)
  }

  func testCosineSimilarityOfMismatchedLengthsIsZero() {
    let similarity = NamiAiContextualEmbeddingScorer.cosineSimilarity([1, 2], [1, 2, 3])
    XCTAssertEqual(similarity, 0.0, accuracy: 0.0001)
  }

  func testCosineSimilarityOfEmptyVectorsIsZero() {
    let similarity = NamiAiContextualEmbeddingScorer.cosineSimilarity([], [])
    XCTAssertEqual(similarity, 0.0, accuracy: 0.0001)
  }

  func testCosineSimilarityOfZeroVectorIsZero() {
    // Guards the normA/normB > 0 check - a zero vector has no direction, so similarity is
    // defined as 0 rather than dividing by zero.
    let similarity = NamiAiContextualEmbeddingScorer.cosineSimilarity([0, 0, 0], [1, 2, 3])
    XCTAssertEqual(similarity, 0.0, accuracy: 0.0001)
  }
}
