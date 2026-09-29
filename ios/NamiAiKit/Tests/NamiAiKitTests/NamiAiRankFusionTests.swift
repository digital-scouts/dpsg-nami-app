import XCTest

@testable import NamiAiKit

final class NamiAiRankFusionTests: XCTestCase {
  func testItemRankedFirstInBothRankingsWins() {
    let scores = NamiAiRankFusion.reciprocalRankFusion(rankings: [[0, 1, 2], [0, 2, 1]])

    XCTAssertEqual(scores.max { $0.value < $1.value }?.key, 0)
  }

  func testItemMissingFromOneRankingStillGetsCreditFromTheOther() {
    // Item 5 only appears in the second ranking, at rank 1 - it should still show up with a
    // non-zero score, not be excluded just because the first ranking never delivered it.
    let scores = NamiAiRankFusion.reciprocalRankFusion(rankings: [[0, 1, 2], [5]])

    XCTAssertNotNil(scores[5])
    XCTAssertNil(scores[99])
  }

  func testEmptyRankingsProduceNoScores() {
    let scores = NamiAiRankFusion.reciprocalRankFusion(rankings: [[], []])

    XCTAssertTrue(scores.isEmpty)
  }

  func testHigherKDampensRankDifferences() {
    // With a very large k, 1/(k+rank) barely differs between adjacent ranks - the score spread
    // across items should shrink as k grows.
    let smallK = NamiAiRankFusion.reciprocalRankFusion(rankings: [[0, 1]], k: 1)
    let largeK = NamiAiRankFusion.reciprocalRankFusion(rankings: [[0, 1]], k: 1000)

    let smallKSpread = smallK[0]! - smallK[1]!
    let largeKSpread = largeK[0]! - largeK[1]!
    XCTAssertGreaterThan(smallKSpread, largeKSpread)
  }
}
