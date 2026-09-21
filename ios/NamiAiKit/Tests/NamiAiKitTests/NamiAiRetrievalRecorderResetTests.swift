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
    var chunks = await recorder.deliveredChunks
    XCTAssertFalse(keys.isEmpty)
    XCTAssertFalse(texts.isEmpty)
    XCTAssertFalse(chunks.isEmpty)

    await recorder.reset()

    keys = await recorder.deliveredKeys
    texts = await recorder.deliveredChunkRefs
    chunks = await recorder.deliveredChunks
    XCTAssertTrue(keys.isEmpty)
    XCTAssertTrue(texts.isEmpty)
    XCTAssertTrue(chunks.isEmpty)
  }

  func testRecordStoresCompactDocIdSectionRefsNotFullText() async {
    let recorder = NamiAiRetrievalRecorder()
    await recorder.record([makeChunk(sectionNumber: "31")])

    let refs = await recorder.deliveredChunkRefs

    XCTAssertEqual(refs, ["satzung_stamm#31"])
  }

  func testRecordStoresFullChunksAlongsideRefs() async {
    let recorder = NamiAiRetrievalRecorder()
    await recorder.record([makeChunk(sectionNumber: "31")])

    let chunks = await recorder.deliveredChunks

    XCTAssertEqual(chunks.map(\.sectionNumber), ["31"])
    XCTAssertEqual(chunks.map(\.text), ["chunk text 31"])
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
