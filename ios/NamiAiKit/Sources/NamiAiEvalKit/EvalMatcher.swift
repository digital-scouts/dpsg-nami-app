import Foundation
import NamiAiKit

/// Result of comparing an answer's cited sources against a fixture's expected_sources.
public struct EvalSourceMatchResult: Equatable, Sendable {
  public let ok: Bool
  public let matchedExpected: [EvalExpectedSource]
  public let missingExpected: [EvalExpectedSource]
  /// Cited docTitles that EvalCorpusTitleIndex couldn't resolve to a known doc_id - a
  /// data-quality signal (hallucinated or stale title), reported separately from a plain
  /// source-mismatch so it's not silently conflated with "wrong section number".
  public let citedTitlesUnresolvable: [String]
}

/// Pure, model-independent comparison logic shared by EvalTurnOrchestrator - no FoundationModels
/// dependency, so it's exercised directly in EvalMatcherTests without a real device/model.
public enum EvalMatcher {
  /// match_mode "all": every expected source must be cited. match_mode "any" (or any other
  /// value): at least one expected source must be cited. An empty `expected` with match_mode
  /// "all" is only ok when nothing was cited either (mirrors expects_reject: true fixtures,
  /// which carry an empty expected_sources list).
  public static func matchSources(
    citedSources: [NamiAiSourceRef],
    expected: [EvalExpectedSource],
    matchMode: String,
    titleIndex: EvalCorpusTitleIndex
  ) -> EvalSourceMatchResult {
    var citedKeys: Set<EvalExpectedSource> = []
    var unresolvable: [String] = []
    for source in citedSources {
      guard let docId = titleIndex.docId(forCitedTitle: source.docTitle) else {
        unresolvable.append(source.docTitle)
        continue
      }
      citedKeys.insert(EvalExpectedSource(docId: docId, sectionNumber: source.sectionNumber))
    }

    let matched = expected.filter { citedKeys.contains($0) }
    let missing = expected.filter { !citedKeys.contains($0) }

    let ok: Bool
    if expected.isEmpty {
      ok = citedKeys.isEmpty
    } else if matchMode == "all" {
      ok = missing.isEmpty
    } else {
      ok = !matched.isEmpty
    }

    return EvalSourceMatchResult(
      ok: ok, matchedExpected: matched, missingExpected: missing,
      citedTitlesUnresolvable: unresolvable)
  }

  /// expects_reject fixtures must come back unclear; answerable fixtures must not. Both
  /// directions count as a guardrail failure (wrongly rejecting an answerable question is as
  /// much a failure as wrongly answering a question that should have been rejected).
  public static func matchGuardrail(expectsReject: Bool, answerUnclear: Bool) -> Bool {
    expectsReject == answerUnclear
  }

  /// Consistency across --repeat runs of the same fixture: every repeat must land on the same
  /// pass/fail verdict. The answer TEXT is allowed to vary between repeats (the model isn't
  /// deterministic, see chat_ai/eval/README.md "Bekannte Grenzen") - only the computed verdict
  /// needs to hold steady for a fixture to count as consistent.
  public static func isConsistent(_ results: [Bool]) -> Bool {
    guard let first = results.first else { return true }
    return results.allSatisfy { $0 == first }
  }
}

extension EvalExpectedSource: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(docId)
    hasher.combine(sectionNumber)
  }
}
