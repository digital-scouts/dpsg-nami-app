import XCTest

@testable import NamiAiEvalKit
@testable import NamiAiKit

/// Fake EvalSessionDriving: hands out pre-scripted outcomes in call order and records every
/// call, so tests can assert on repeat counts, turn indexing, and error short-circuiting without
/// any real NamiAiKit/FoundationModels call.
private actor FakeEvalSessionDriver: EvalSessionDriving {
  private var startSessionOutcomes: [EvalAsyncOutcome<String>]
  private var respondOutcomes: [EvalAsyncOutcome<NamiAiAnswer>]

  private(set) var startSessionSelfCorrectionFlags: [Bool] = []
  private(set) var respondCalls: [(sessionId: String, prompt: String)] = []
  private(set) var endSessionCalls: [String] = []

  init(
    startSessionOutcomes: [EvalAsyncOutcome<String>],
    respondOutcomes: [EvalAsyncOutcome<NamiAiAnswer>]
  ) {
    self.startSessionOutcomes = startSessionOutcomes
    self.respondOutcomes = respondOutcomes
  }

  func startSession(selfCorrectionEnabled: Bool) async -> EvalAsyncOutcome<String> {
    startSessionSelfCorrectionFlags.append(selfCorrectionEnabled)
    guard !startSessionOutcomes.isEmpty else { return .failure(.sessionNotFound) }
    return startSessionOutcomes.removeFirst()
  }

  func streamRespond(sessionId: String, to prompt: String) async -> EvalAsyncOutcome<NamiAiAnswer> {
    respondCalls.append((sessionId, prompt))
    guard !respondOutcomes.isEmpty else { return .failure(.generationFailed) }
    return respondOutcomes.removeFirst()
  }

  func endSession(sessionId: String) async {
    endSessionCalls.append(sessionId)
  }
}

final class EvalTurnOrchestratorTests: XCTestCase {

  private func makeAnswer(
    text: String = "Antwort", sources: [NamiAiSourceRef] = [], unclear: Bool = false
  ) -> NamiAiAnswer {
    NamiAiAnswer(
      text: text, contextChunks: ["satzung_stamm#20"], sources: sources, unclear: unclear,
      contextTruncated: false, verificationFailed: false, verificationAttempts: [])
  }

  private func makeQuestion(
    id: String = "q1", expectedSources: [EvalExpectedSource] = [], matchMode: String = "all",
    expectsReject: Bool = false
  ) -> EvalQuestionFixture {
    EvalQuestionFixture(
      id: id, category: "general", question: "Frage?", expectedSources: expectedSources,
      matchMode: matchMode, expectsReject: expectsReject, automatedCheck: true, note: nil)
  }

  private func makeTitleIndex() throws -> EvalCorpusTitleIndex {
    try EvalCorpusTitleIndex(chunks: [("satzung_stamm", "Satzung Stamm")])
  }

  // MARK: - runQuestion

  func testRunQuestionRunsOneFreshSessionPerRepeat() async throws {
    let titleIndex = try makeTitleIndex()
    let answer = makeAnswer()
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.success("session-0"), .success("session-1"), .success("session-2")],
      respondOutcomes: [.success(answer), .success(answer), .success(answer)])
    let config = EvalRunConfig(runId: "run", repeatCount: 3, defaultSelfCorrectionEnabled: false)

    let entries = await EvalTurnOrchestrator.runQuestion(
      makeQuestion(), driver: driver, titleIndex: titleIndex, config: config)

    XCTAssertEqual(entries.count, 3)
    XCTAssertEqual(entries.map(\.repeatIndex), [0, 1, 2])
    XCTAssertEqual(entries.map(\.turnIndex), [1, 1, 1])
    XCTAssertEqual(entries.map(\.sessionId), ["session-0", "session-1", "session-2"])
    XCTAssertEqual(entries.map(\.outcome), ["success", "success", "success"])

    let endSessionCalls = await driver.endSessionCalls
    XCTAssertEqual(endSessionCalls, ["session-0", "session-1", "session-2"])
  }

  func testRunQuestionLogsErrorAndSkipsRespondWhenStartSessionFails() async throws {
    let titleIndex = try makeTitleIndex()
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.failure(.appleIntelligenceNotEnabled)], respondOutcomes: [])
    let config = EvalRunConfig(runId: "run", repeatCount: 1, defaultSelfCorrectionEnabled: false)

    let entries = await EvalTurnOrchestrator.runQuestion(
      makeQuestion(), driver: driver, titleIndex: titleIndex, config: config)

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "error")
    XCTAssertEqual(entries[0].errorCode, NamiAiError.appleIntelligenceNotEnabled.flutterErrorCode)
    XCTAssertNil(entries[0].sessionId)
    XCTAssertFalse(entries[0].sourceMatch)
    XCTAssertFalse(entries[0].guardrailMatch)

    let respondCalls = await driver.respondCalls
    XCTAssertTrue(respondCalls.isEmpty)
    let endSessionCalls = await driver.endSessionCalls
    XCTAssertTrue(endSessionCalls.isEmpty)
  }

  func testRunQuestionMarksTimeoutOutcomeDistinctlyFromError() async throws {
    let titleIndex = try makeTitleIndex()
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.success("session-0")], respondOutcomes: [.timedOut])
    let config = EvalRunConfig(runId: "run", repeatCount: 1, defaultSelfCorrectionEnabled: false)

    let entries = await EvalTurnOrchestrator.runQuestion(
      makeQuestion(), driver: driver, titleIndex: titleIndex, config: config)

    XCTAssertEqual(entries[0].outcome, "timeout")
    XCTAssertEqual(entries[0].errorCode, "eval_timeout")
  }

  func testRunQuestionComputesSourceAndGuardrailMatch() async throws {
    let titleIndex = try makeTitleIndex()
    let answer = makeAnswer(
      sources: [
        NamiAiSourceRef(docTitle: "Satzung Stamm", sectionNumber: "20", docStand: "Mai 2024")
      ])
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.success("session-0")], respondOutcomes: [.success(answer)])
    let question = makeQuestion(
      expectedSources: [EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "20")],
      matchMode: "all", expectsReject: false)
    let config = EvalRunConfig(runId: "run", repeatCount: 1, defaultSelfCorrectionEnabled: false)

    let entries = await EvalTurnOrchestrator.runQuestion(
      question, driver: driver, titleIndex: titleIndex, config: config)

    XCTAssertTrue(entries[0].sourceMatch)
    XCTAssertTrue(entries[0].guardrailMatch)
  }

  // MARK: - runConversation

  private func makeConversation(
    id: String = "conv1", selfCorrectionEnabled: Bool? = nil,
    turns: [EvalConversationTurnFixture]
  ) -> EvalConversationFixture {
    EvalConversationFixture(
      id: id, category: "general", selfCorrectionEnabled: selfCorrectionEnabled, turns: turns)
  }

  private func makeTurn(question: String) -> EvalConversationTurnFixture {
    EvalConversationTurnFixture(
      question: question, expectedSources: [], matchMode: "all", expectsReject: false, note: nil)
  }

  func testRunConversationUsesOneHeldSessionAcrossAllTurns() async throws {
    let titleIndex = try makeTitleIndex()
    let answer = makeAnswer()
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.success("session-0")],
      respondOutcomes: [.success(answer), .success(answer)])
    let conversation = makeConversation(turns: [
      makeTurn(question: "Frage 1"), makeTurn(question: "Und wer wählt ihn?"),
    ])
    let config = EvalRunConfig(runId: "run", repeatCount: 1, defaultSelfCorrectionEnabled: false)

    let entries = await EvalTurnOrchestrator.runConversation(
      conversation, driver: driver, titleIndex: titleIndex, config: config)

    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries.map(\.turnIndex), [1, 2])
    XCTAssertEqual(entries.map(\.sessionId), ["session-0", "session-0"])
    XCTAssertEqual(entries.map(\.conversationId), ["conv1", "conv1"])

    let respondCalls = await driver.respondCalls
    XCTAssertEqual(respondCalls.map(\.prompt), ["Frage 1", "Und wer wählt ihn?"])
    let endSessionCalls = await driver.endSessionCalls
    XCTAssertEqual(endSessionCalls, ["session-0"])
  }

  func testRunConversationStopsEarlyOnFirstFailedTurnButStillEndsSession() async throws {
    let titleIndex = try makeTitleIndex()
    let answer = makeAnswer()
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.success("session-0")],
      respondOutcomes: [.failure(.generationFailed), .success(answer)])
    let conversation = makeConversation(turns: [
      makeTurn(question: "Frage 1"), makeTurn(question: "Frage 2"),
    ])
    let config = EvalRunConfig(runId: "run", repeatCount: 1, defaultSelfCorrectionEnabled: false)

    let entries = await EvalTurnOrchestrator.runConversation(
      conversation, driver: driver, titleIndex: titleIndex, config: config)

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "error")
    let respondCalls = await driver.respondCalls
    XCTAssertEqual(respondCalls.count, 1)
    let endSessionCalls = await driver.endSessionCalls
    XCTAssertEqual(endSessionCalls, ["session-0"])
  }

  func testRunConversationRepeatsCreateFreshSessionsEachTime() async throws {
    let titleIndex = try makeTitleIndex()
    let answer = makeAnswer()
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.success("session-0"), .success("session-1")],
      respondOutcomes: [.success(answer), .success(answer)])
    let conversation = makeConversation(turns: [makeTurn(question: "Frage 1")])
    let config = EvalRunConfig(runId: "run", repeatCount: 2, defaultSelfCorrectionEnabled: false)

    let entries = await EvalTurnOrchestrator.runConversation(
      conversation, driver: driver, titleIndex: titleIndex, config: config)

    XCTAssertEqual(entries.map(\.repeatIndex), [0, 1])
    XCTAssertEqual(entries.map(\.sessionId), ["session-0", "session-1"])
  }

  func testRunConversationPassesPerConversationSelfCorrectionOverride() async throws {
    let titleIndex = try makeTitleIndex()
    let answer = makeAnswer()
    let driver = FakeEvalSessionDriver(
      startSessionOutcomes: [.success("session-0")], respondOutcomes: [.success(answer)])
    let conversation = makeConversation(
      selfCorrectionEnabled: true, turns: [makeTurn(question: "Frage 1")])
    let config = EvalRunConfig(runId: "run", repeatCount: 1, defaultSelfCorrectionEnabled: false)

    _ = await EvalTurnOrchestrator.runConversation(
      conversation, driver: driver, titleIndex: titleIndex, config: config)

    let flags = await driver.startSessionSelfCorrectionFlags
    XCTAssertEqual(flags, [true])
  }
}
