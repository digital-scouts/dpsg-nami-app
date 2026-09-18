import XCTest

@testable import NamiAiKit

final class NamiAiContextTests: XCTestCase {
  func testLoadChunksReturnsExactly32NonEmptyStrings() {
    let chunks = NamiAiContext.loadChunks()
    XCTAssertNotNil(chunks)
    XCTAssertEqual(chunks?.count, 32)
    XCTAssertTrue(chunks?.allSatisfy { !$0.isEmpty } ?? false)
  }
}
