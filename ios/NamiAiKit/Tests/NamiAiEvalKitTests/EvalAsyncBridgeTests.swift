import XCTest

@testable import NamiAiEvalKit
@testable import NamiAiKit

final class EvalAsyncBridgeTests: XCTestCase {

  func testAwaitingReturnsSuccessWhenCompletionCallsBackImmediately() async {
    let outcome = await EvalAsyncBridge.awaiting(timeoutSeconds: 5) {
      (completion: @escaping (Result<String, NamiAiError>) -> Void) in
      completion(.success("ok"))
    }

    guard case .success(let value) = outcome else {
      return XCTFail("Expected .success, got \(outcome)")
    }
    XCTAssertEqual(value, "ok")
  }

  func testAwaitingReturnsFailureWhenCompletionReportsAnError() async {
    let outcome = await EvalAsyncBridge.awaiting(timeoutSeconds: 5) {
      (completion: @escaping (Result<String, NamiAiError>) -> Void) in
      completion(.failure(.sessionNotFound))
    }

    guard case .failure(let error) = outcome else {
      return XCTFail("Expected .failure, got \(outcome)")
    }
    XCTAssertEqual(error, .sessionNotFound)
  }

  func testAwaitingTimesOutWhenCompletionNeverFires() async {
    let outcome = await EvalAsyncBridge.awaiting(timeoutSeconds: 0.05) {
      (_: @escaping (Result<String, NamiAiError>) -> Void) in
      // Deliberately never calls back - simulates a hung model call.
    }

    guard case .timedOut = outcome else {
      return XCTFail("Expected .timedOut, got \(outcome)")
    }
  }
}

extension EvalAsyncOutcome: CustomStringConvertible {
  public var description: String {
    switch self {
    case .success(let value): return "success(\(value))"
    case .failure(let error): return "failure(\(error))"
    case .timedOut: return "timedOut"
    }
  }
}
