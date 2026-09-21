"""Selbsttest fuer report_eval_run.py (stdlib unittest - das Repo hat kein pytest, siehe
chat_ai/requirements.txt). Deckt nur die pure Aggregations-/Diff-Logik ab, keine echten
Eval-Runs noetig.

Ausfuehren: python3 -m unittest chat_ai/eval/test_report_eval_run.py
"""

from __future__ import annotations

import unittest

from report_eval_run import diff_runs, summarize


def _entry(
    fixture_id: str,
    category: str = "general",
    source_match: bool = True,
    guardrail_match: bool = True,
    latency_ms: int = 100,
    fixture_type: str = "question",
    turn_index: int = 1,
    prompt: str = "Frage?",
    answer: str = "Antwort.",
    outcome: str = "success",
) -> dict:
    return {
        "fixtureId": fixture_id,
        "fixtureType": fixture_type,
        "turnIndex": turn_index,
        "category": category,
        "sourceMatch": source_match,
        "guardrailMatch": guardrail_match,
        "latencyMs": latency_ms,
        "prompt": prompt,
        "answer": answer,
        "outcome": outcome,
    }


class SummarizeTests(unittest.TestCase):
    def test_pass_rate_per_category(self) -> None:
        entries = [
            _entry("q1", category="jargon", source_match=True, guardrail_match=True),
            _entry("q2", category="jargon", source_match=False, guardrail_match=True),
            _entry("q3", category="general", source_match=True, guardrail_match=True),
        ]
        summary = summarize(entries, "run.jsonl")
        by_category = {c.category: c for c in summary.categories}

        self.assertEqual(by_category["jargon"].passed, 1)
        self.assertEqual(by_category["jargon"].total, 2)
        self.assertEqual(by_category["general"].passed, 1)
        self.assertEqual(by_category["general"].total, 1)

    def test_failed_fixtures_listed(self) -> None:
        entries = [
            _entry("q1", source_match=False, guardrail_match=True),
            _entry("q2", source_match=True, guardrail_match=True),
        ]
        summary = summarize(entries, "run.jsonl")
        self.assertEqual([f.fixture_key for f in summary.failed], ["q1"])

    def test_conversation_turns_are_distinct_fixtures(self) -> None:
        entries = [
            _entry("conv1", fixture_type="conversation", turn_index=1, source_match=False, guardrail_match=True),
            _entry("conv1", fixture_type="conversation", turn_index=2, source_match=True, guardrail_match=True),
        ]
        summary = summarize(entries, "run.jsonl")
        failed_keys = [f.fixture_key for f in summary.failed]
        self.assertEqual(failed_keys, ["conv1#turn1"])

    def test_consistency_rate_across_repeats(self) -> None:
        entries = [
            _entry("q1", source_match=True, guardrail_match=True),
            _entry("q1", source_match=True, guardrail_match=True),
            _entry("q2", source_match=True, guardrail_match=True),
            _entry("q2", source_match=False, guardrail_match=True),
        ]
        summary = summarize(entries, "run.jsonl")
        self.assertEqual(summary.consistency_rate, 0.5)
        self.assertEqual(summary.inconsistent_fixture_keys, ["q2"])

    def test_no_consistency_rate_without_repeats(self) -> None:
        entries = [_entry("q1"), _entry("q2")]
        summary = summarize(entries, "run.jsonl")
        self.assertIsNone(summary.consistency_rate)

    def test_latency_stats(self) -> None:
        entries = [_entry("q1", latency_ms=100), _entry("q2", latency_ms=300), _entry("q3", latency_ms=200)]
        summary = summarize(entries, "run.jsonl")
        self.assertIsNotNone(summary.latency)
        assert summary.latency is not None
        self.assertEqual(summary.latency.min_ms, 100)
        self.assertEqual(summary.latency.max_ms, 300)
        self.assertEqual(summary.latency.median_ms, 200)


class DiffTests(unittest.TestCase):
    def test_detects_regression_and_improvement(self) -> None:
        entries_a = [
            _entry("q1", source_match=True, guardrail_match=True, latency_ms=100),
            _entry("q2", source_match=False, guardrail_match=True, latency_ms=100),
        ]
        entries_b = [
            _entry("q1", source_match=False, guardrail_match=True, latency_ms=150),
            _entry("q2", source_match=True, guardrail_match=True, latency_ms=120),
        ]
        diff = diff_runs(entries_a, entries_b, "a.jsonl", "b.jsonl")

        self.assertEqual([d.fixture_key for d in diff.regressions], ["q1"])
        self.assertEqual([d.fixture_key for d in diff.improvements], ["q2"])
        self.assertEqual(diff.unchanged_count, 0)

    def test_uses_last_repeat_per_fixture(self) -> None:
        entries_a = [
            _entry("q1", source_match=False, guardrail_match=True),
            _entry("q1", source_match=True, guardrail_match=True),
        ]
        entries_b = [_entry("q1", source_match=True, guardrail_match=True)]
        diff = diff_runs(entries_a, entries_b, "a.jsonl", "b.jsonl")

        self.assertEqual(diff.regressions, [])
        self.assertEqual(diff.improvements, [])
        self.assertEqual(diff.unchanged_count, 1)


if __name__ == "__main__":
    unittest.main()
