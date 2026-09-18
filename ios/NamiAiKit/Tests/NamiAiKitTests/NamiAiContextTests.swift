import XCTest

@testable import NamiAiKit

final class NamiAiContextTests: XCTestCase {
  func testLoadChunksReturnsExactly38NonEmptyStrings() {
    let chunks = NamiAiContext.loadChunks()
    XCTAssertNotNil(chunks)
    XCTAssertEqual(chunks?.count, 38)
    XCTAssertTrue(chunks?.allSatisfy { !$0.isEmpty } ?? false)
  }
}
