import XCTest

@testable import NamiAiKit

final class NamiAiSlidingWindowTests: XCTestCase {
  private enum Entry: Equatable {
    case instructions
    case prompt(String)
    case response(String)
  }

  private func isInstructions(_ entry: Entry) -> Bool {
    if case .instructions = entry { return true }
    return false
  }

  private func isTurnBoundary(_ entry: Entry) -> Bool {
    if case .response = entry { return true }
    return false
  }

  func testFewerTurnsThanLimitReturnsEntriesUnchanged() {
    let entries: [Entry] = [.instructions, .prompt("1"), .response("a")]

    let result = NamiAiSlidingWindow.truncated(
      entries, keepLastTurns: 2, isInstructions: isInstructions, isTurnBoundary: isTurnBoundary)

    XCTAssertEqual(result, entries)
  }

  func testExactlyLimitTurnsReturnsEntriesUnchanged() {
    let entries: [Entry] = [
      .instructions, .prompt("1"), .response("a"), .prompt("2"), .response("b"),
    ]

    let result = NamiAiSlidingWindow.truncated(
      entries, keepLastTurns: 2, isInstructions: isInstructions, isTurnBoundary: isTurnBoundary)

    XCTAssertEqual(result, entries)
  }

  func testMoreTurnsThanLimitKeepsOnlyLastNTurnsPlusInstructions() {
    let entries: [Entry] = [
      .instructions,
      .prompt("1"), .response("a"),
      .prompt("2"), .response("b"),
      .prompt("3"), .response("c"),
    ]

    let result = NamiAiSlidingWindow.truncated(
      entries, keepLastTurns: 2, isInstructions: isInstructions, isTurnBoundary: isTurnBoundary)

    XCTAssertEqual(
      result,
      [.instructions, .prompt("2"), .response("b"), .prompt("3"), .response("c")])
  }

  func testKeepLastOneTurnKeepsOnlyMostRecentTurn() {
    let entries: [Entry] = [
      .instructions,
      .prompt("1"), .response("a"),
      .prompt("2"), .response("b"),
    ]

    let result = NamiAiSlidingWindow.truncated(
      entries, keepLastTurns: 1, isInstructions: isInstructions, isTurnBoundary: isTurnBoundary)

    XCTAssertEqual(result, [.instructions, .prompt("2"), .response("b")])
  }

  func testInstructionsKeptEvenWhenNotFirstEntry() {
    let entries: [Entry] = [
      .prompt("stray"), .instructions,
      .prompt("1"), .response("a"),
      .prompt("2"), .response("b"),
      .prompt("3"), .response("c"),
    ]

    let result = NamiAiSlidingWindow.truncated(
      entries, keepLastTurns: 1, isInstructions: isInstructions, isTurnBoundary: isTurnBoundary)

    XCTAssertEqual(result, [.instructions, .prompt("3"), .response("c")])
  }

  func testNoTurnBoundariesReturnsEntriesUnchanged() {
    let entries: [Entry] = [.instructions, .prompt("dangling, no response yet")]

    let result = NamiAiSlidingWindow.truncated(
      entries, keepLastTurns: 2, isInstructions: isInstructions, isTurnBoundary: isTurnBoundary)

    XCTAssertEqual(result, entries)
  }
}
