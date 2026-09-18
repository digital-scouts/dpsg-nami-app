import XCTest

@testable import NamiAiKit

final class NamiAiRetrievalTests: XCTestCase {
  private func makeChunk(
    docTitle: String = "Satzung Stamm",
    sectionNumber: String,
    text: String
  ) -> NamiAiChunk {
    NamiAiChunk(
      docId: "satzung_stamm",
      ebene: "Stamm",
      docTitle: docTitle,
      docStand: "Mai 2024",
      sectionNumber: sectionNumber,
      sectionTitle: "Test",
      pageStart: 1,
      pageEnd: 1,
      text: text,
      sourceFile: "test.pdf"
    )
  }

  func testTopMatchesRanksExactTermMatchFirst() {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand."),
      makeChunk(sectionNumber: "2", text: "Der Bezirk gliedert sich in mehrere Stämme."),
      makeChunk(
        sectionNumber: "3",
        text: "Die Stammesversammlung tritt mindestens einmal jährlich zusammen."
      ),
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Stammesversammlung", limit: 5)

    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(Set(matches.map(\.sectionNumber)), ["1", "3"])
  }

  func testTopMatchesReturnsEmptyForUnrelatedQuery() {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand."),
      makeChunk(sectionNumber: "2", text: "Der Bezirk gliedert sich in mehrere Stämme."),
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Vulkanausbruch Island")

    XCTAssertTrue(matches.isEmpty)
  }

  func testTopMatchesRespectsLimit() {
    let chunks = (1...10).map {
      makeChunk(sectionNumber: "\($0)", text: "Die Stammesversammlung regelt Ziffer \($0).")
    }
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Stammesversammlung", limit: 3)

    XCTAssertEqual(matches.count, 3)
  }

  func testEmptyCorpusReturnsNoMatches() {
    let index = NamiAiRetrievalIndex(chunks: [])

    XCTAssertTrue(index.topMatches(for: "Stammesversammlung").isEmpty)
  }
}
