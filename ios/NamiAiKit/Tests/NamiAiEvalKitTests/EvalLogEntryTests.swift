import XCTest

@testable import NamiAiEvalKit
@testable import NamiAiKit

final class EvalLogEntryTests: XCTestCase {

  private func makeEntry() -> EvalLogEntry {
    EvalLogEntry(
      timestamp: "2026-09-21T10:00:00Z", runId: "run-1", requestId: "req-1",
      fixtureType: "question", fixtureId: "jargon-sv-mitglieder", conversationId: nil,
      repeatIndex: 0, sessionId: "session-1", turnIndex: 1,
      prompt: "Wer gehört zur Stammesversammlung?", outcome: "success",
      answer: "Antworttext", contextChunks: ["satzung_stamm#20"],
      sources: [
        EvalLoggedSource(
          NamiAiSourceRef(docTitle: "Satzung Stamm", sectionNumber: "20", docStand: "Mai 2024"))
      ],
      unclear: false, contextTruncated: false, verificationFailed: false,
      verificationAttempts: [], errorCode: nil, errorMessage: nil, latencyMs: 1234,
      osVersion: "macOS 26.0", category: "jargon",
      expectedSources: [EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "20")],
      matchMode: "all", expectsReject: false, sourceMatch: true, guardrailMatch: true,
      selfCorrectionEnabled: false)
  }

  /// Stable JSON key names matter here: chat_ai/eval/report_eval_run.py reads this schema
  /// directly, so a silent rename would break the report tool without a compiler error.
  func testEncodesAllExpectedTopLevelKeys() throws {
    let data = try JSONEncoder().encode(makeEntry())
    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any])

    let expectedKeys: Set<String> = [
      "timestamp", "runId", "requestId", "fixtureType", "fixtureId", "conversationId",
      "repeatIndex", "sessionId", "turnIndex", "prompt", "outcome", "answer", "contextChunks",
      "chunkCount", "sources", "unclear", "contextTruncated", "verificationFailed",
      "verificationAttempts", "errorCode", "errorMessage", "latencyMs", "osVersion", "category",
      "expectedSources", "matchMode", "expectsReject", "sourceMatch", "guardrailMatch",
      "selfCorrectionEnabled",
    ]
    XCTAssertEqual(Set(object.keys), expectedKeys)
  }

  func testChunkCountIsDerivedFromContextChunks() throws {
    let data = try JSONEncoder().encode(makeEntry())
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(object["chunkCount"] as? Int, 1)
  }

  func testNilOptionalFieldsEncodeAsJSONNull() throws {
    let data = try JSONEncoder().encode(makeEntry())
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertTrue(object["conversationId"] is NSNull)
    XCTAssertTrue(object["errorCode"] is NSNull)
    XCTAssertTrue(object["errorMessage"] is NSNull)
  }
}
