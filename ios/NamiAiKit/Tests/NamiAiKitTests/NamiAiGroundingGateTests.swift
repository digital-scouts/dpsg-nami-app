import XCTest

@testable import NamiAiKit

final class NamiAiGroundingGateTests: XCTestCase {
  private let deliveredKey = NamiAiChunkKey(docTitle: "Satzung Stamm", sectionNumber: "24")

  func testVerifiedSourceIsKept() {
    let source = NamiAiSourceRef(
      docTitle: "Satzung Stamm", sectionNumber: "24", docStand: "Mai 2024")

    let answer = NamiAiGroundingGate.verify(
      text: "Antwort",
      sources: [source],
      unclear: false,
      deliveredKeys: [deliveredKey],
      contextChunks: ["chunk text"]
    )

    XCTAssertEqual(answer.sources, [source])
    XCTAssertFalse(answer.unclear)
  }

  func testUnretrievedSourceIsFilteredOutAndForcesUnclear() {
    let claimedButNeverRetrieved = NamiAiSourceRef(
      docTitle: "Satzung Stamm", sectionNumber: "99", docStand: "Mai 2024")

    let answer = NamiAiGroundingGate.verify(
      text: "Antwort mit erfundener Quelle",
      sources: [claimedButNeverRetrieved],
      unclear: false,
      deliveredKeys: [deliveredKey],
      contextChunks: ["chunk text"]
    )

    XCTAssertTrue(answer.sources.isEmpty)
    XCTAssertTrue(answer.unclear)
  }

  func testMixOfVerifiedAndUnverifiedKeepsOnlyVerified() {
    let verified = NamiAiSourceRef(
      docTitle: "Satzung Stamm", sectionNumber: "24", docStand: "Mai 2024")
    let unverified = NamiAiSourceRef(
      docTitle: "Satzung Bund", sectionNumber: "5", docStand: "Mai 2024")

    let answer = NamiAiGroundingGate.verify(
      text: "Antwort",
      sources: [verified, unverified],
      unclear: false,
      deliveredKeys: [deliveredKey],
      contextChunks: []
    )

    XCTAssertEqual(answer.sources, [verified])
    XCTAssertFalse(answer.unclear)
  }

  func testModelDeclaredUnclearStaysUnclearEvenWithVerifiedSource() {
    let source = NamiAiSourceRef(
      docTitle: "Satzung Stamm", sectionNumber: "24", docStand: "Mai 2024")

    let answer = NamiAiGroundingGate.verify(
      text: "Unsichere Antwort",
      sources: [source],
      unclear: true,
      deliveredKeys: [deliveredKey],
      contextChunks: []
    )

    XCTAssertTrue(answer.unclear)
  }

  func testNoSourcesAndNoDeliveredChunksStaysUnclear() {
    let answer = NamiAiGroundingGate.verify(
      text: "Dazu liegt mir keine Quelle vor.",
      sources: [],
      unclear: true,
      deliveredKeys: [],
      contextChunks: []
    )

    XCTAssertTrue(answer.sources.isEmpty)
    XCTAssertTrue(answer.unclear)
  }
}
