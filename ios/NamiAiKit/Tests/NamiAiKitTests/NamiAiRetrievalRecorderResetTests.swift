import XCTest

@testable import NamiAiKit

final class NamiAiRetrievalRecorderResetTests: XCTestCase {
  private func makeChunk(sectionNumber: String) -> NamiAiChunk {
    NamiAiChunk(
      docId: "satzung_stamm",
      ebene: "Stamm",
      docTitle: "Satzung Stamm",
      docStand: "Mai 2024",
      sectionNumber: sectionNumber,
      sectionTitle: "Test",
      pageStart: 1,
      pageEnd: 1,
      text: "chunk text \(sectionNumber)",
      sourceFile: "test.pdf"
    )
  }

  func testResetClearsDeliveredKeysAndChunkTexts() async {
    let recorder = NamiAiRetrievalRecorder()
    await recorder.record([makeChunk(sectionNumber: "24")])
    var keys = await recorder.deliveredKeys
    var texts = await recorder.deliveredChunkRefs
    XCTAssertFalse(keys.isEmpty)
    XCTAssertFalse(texts.isEmpty)

    await recorder.reset()

    keys = await recorder.deliveredKeys
    texts = await recorder.deliveredChunkRefs
    XCTAssertTrue(keys.isEmpty)
    XCTAssertTrue(texts.isEmpty)
  }

  func testRecordStoresCompactDocIdSectionRefsNotFullText() async {
    let recorder = NamiAiRetrievalRecorder()
    await recorder.record([makeChunk(sectionNumber: "31")])

    let refs = await recorder.deliveredChunkRefs

    XCTAssertEqual(refs, ["satzung_stamm#31"])
  }

  func testRecordAfterResetStartsFromEmpty() async {
    let recorder = NamiAiRetrievalRecorder()
    await recorder.record([makeChunk(sectionNumber: "24")])
    await recorder.reset()

    await recorder.record([makeChunk(sectionNumber: "48")])

    let keys = await recorder.deliveredKeys
    XCTAssertEqual(keys, [NamiAiChunkKey(docTitle: "Satzung Stamm", sectionNumber: "48")])
  }
}
