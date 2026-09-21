import XCTest

@testable import NamiAiKit

#if canImport(FoundationModels)
  import FoundationModels

  final class NamiAiChatSessionStoreTests: XCTestCase {
    func testStartSessionReturnsUniqueIds() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for LanguageModelSession")
      }
      let store = NamiAiChatSessionStore()

      let firstId = await store.startSession(selfCorrectionEnabled: false)
      let secondId = await store.startSession(selfCorrectionEnabled: false)

      XCTAssertNotEqual(firstId, secondId)
    }

    func testSessionForReturnsStartedSession() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for LanguageModelSession")
      }
      let store = NamiAiChatSessionStore()
      let id = await store.startSession(selfCorrectionEnabled: false)

      let session = await store.session(for: id)

      XCTAssertNotNil(session)
      XCTAssertEqual(session?.id, id)
    }

    func testSessionForUnknownIdReturnsNil() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for LanguageModelSession")
      }
      let store = NamiAiChatSessionStore()

      let session = await store.session(for: "unknown")

      XCTAssertNil(session)
    }

    func testEndSessionRemovesIt() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for LanguageModelSession")
      }
      let store = NamiAiChatSessionStore()
      let id = await store.startSession(selfCorrectionEnabled: false)

      await store.endSession(id)

      let session = await store.session(for: id)
      XCTAssertNil(session)
    }

    func testEndSessionForUnknownIdIsNoOp() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for LanguageModelSession")
      }
      let store = NamiAiChatSessionStore()

      await store.endSession("unknown")
    }
  }
#endif
