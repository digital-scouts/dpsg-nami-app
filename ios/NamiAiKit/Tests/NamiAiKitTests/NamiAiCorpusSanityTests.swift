import XCTest

@testable import NamiAiKit

/// Light structural check against the real production corpus (chat_ai/build_chunks.py output,
/// specs/nami-ai-roadmap.md section 3.4), read via a relative repo path - no Flutter runtime
/// needed since this test runs inside the same monorepo checkout. Deliberately not the fixture
/// used by NamiAiRetrievalTests, to avoid coupling scoring assertions to production data drift.
final class NamiAiCorpusSanityTests: XCTestCase {
  private static let expectedDocIds: Set<String> = [
    "satzung_stamm", "satzung_bezirk", "satzung_dioezese", "satzung_bund", "ordnung",
  ]

  func testProductionCorpusLoadsWithAllDocumentsAndRequiredFields() throws {
    let corpusURL = Self.repoRootURL()
      .appendingPathComponent("assets/ai_kontext/nami_ai_corpus_v1.json")
    guard FileManager.default.fileExists(atPath: corpusURL.path) else {
      throw XCTSkip(
        "Produktionskorpus nicht gefunden unter \(corpusURL.path) - Test läuft nur im vollständigen Repo-Checkout."
      )
    }

    NamiAiCorpus.configure(fileURL: corpusURL)
    guard let index = NamiAiCorpus.index() else {
      XCTFail("Korpus konnte nicht geladen/geparst werden")
      return
    }

    XCTAssertFalse(index.chunks.isEmpty)
    XCTAssertEqual(Set(index.chunks.map(\.docId)), Self.expectedDocIds)
    for chunk in index.chunks {
      XCTAssertFalse(chunk.docTitle.isEmpty)
      XCTAssertFalse(chunk.sectionNumber.isEmpty)
      XCTAssertFalse(chunk.docStand.isEmpty)
      XCTAssertFalse(chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }

  /// ios/NamiAiKit/Tests/NamiAiKitTests/<file> -> repo root is five levels up.
  private static func repoRootURL() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 {
      url.deleteLastPathComponent()
    }
    return url
  }
}
