"""Report-/Vergleichswerkzeug fuer NaMi-AI-Eval-Runs (specs/nami-ai-roadmap.md, Abschnitt 3.8).

Liest ein oder zwei JSONL-Log-Dateien, wie sie `swift run nami-ai-eval`
(ios/NamiAiKit/Sources/NamiAiEvalCLI) schreibt, und fasst sie zu einer kompakten
Markdown-Zusammenfassung zusammen - Ersatz fuer das manuelle Ausfuellen von
chat_ai/eval/results/*.md fuer den automatisiert pruefbaren Teil (zitierte
Quellen vs. expected_sources, Guardrail-Verhalten, Konsistenz ueber
Wiederholungen). Die inhaltliche Korrektheits-/Halluzinations-Einschaetzung per
Auge bleibt weiterhin manuell (siehe chat_ai/eval/README.md).

Nutzung:
    python3 chat_ai/eval/report_eval_run.py summarize <run.jsonl> [--output PFAD.md]
    python3 chat_ai/eval/report_eval_run.py diff <run_a.jsonl> <run_b.jsonl> [--output PFAD.md]
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


def load_jsonl(path: Path) -> list[dict]:
    entries: list[dict] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError as error:
                print(f"WARNUNG: Zeile {line_number} in {path} nicht lesbar: {error}", file=sys.stderr)
    return entries


def _fixture_key(entry: dict) -> str:
    """Identifies one fixture across repeats/turns - a question's fixtureId, or a conversation's
    fixtureId + turnIndex (different turns of the same conversation are different checks)."""
    if entry.get("fixtureType") == "conversation":
        return f"{entry['fixtureId']}#turn{entry['turnIndex']}"
    return entry["fixtureId"]


def _passed(entry: dict) -> bool:
    return bool(entry.get("sourceMatch")) and bool(entry.get("guardrailMatch"))


@dataclass
class CategorySummary:
    category: str
    total: int
    passed: int

    @property
    def pass_rate(self) -> float:
        return self.passed / self.total if self.total else 0.0


@dataclass
class LatencyStats:
    count: int
    min_ms: float
    median_ms: float
    p90_ms: float
    max_ms: float


@dataclass
class FailedFixture:
    fixture_key: str
    category: str
    prompt: str
    answer_excerpt: str
    outcome: str


@dataclass
class ReportSummary:
    run_path: str
    total_entries: int
    categories: list[CategorySummary]
    latency: Optional[LatencyStats]
    consistency_rate: Optional[float]
    inconsistent_fixture_keys: list[str]
    failed: list[FailedFixture]


def _latency_stats(entries: list[dict]) -> Optional[LatencyStats]:
    values = sorted(e["latencyMs"] for e in entries if isinstance(e.get("latencyMs"), (int, float)))
    if not values:
        return None
    p90_index = min(len(values) - 1, int(round(0.9 * (len(values) - 1))))
    return LatencyStats(
        count=len(values),
        min_ms=values[0],
        median_ms=statistics.median(values),
        p90_ms=values[p90_index],
        max_ms=values[-1],
    )


def _consistency(entries: list[dict]) -> tuple[Optional[float], list[str]]:
    """Consistency across --repeat runs of the same fixture: a fixture is consistent when every
    repeat lands on the same pass/fail verdict (mirrors EvalMatcher.isConsistent in Swift)."""
    by_fixture: dict[str, list[bool]] = defaultdict(list)
    for entry in entries:
        by_fixture[_fixture_key(entry)].append(_passed(entry))

    repeated = {key: verdicts for key, verdicts in by_fixture.items() if len(verdicts) > 1}
    if not repeated:
        return None, []

    inconsistent = [key for key, verdicts in repeated.items() if len(set(verdicts)) > 1]
    rate = 1 - (len(inconsistent) / len(repeated))
    return rate, sorted(inconsistent)


def summarize(entries: list[dict], run_path: str) -> ReportSummary:
    by_category: dict[str, list[dict]] = defaultdict(list)
    for entry in entries:
        by_category[entry.get("category", "unbekannt")].append(entry)

    categories = [
        CategorySummary(
            category=category,
            total=len(items),
            passed=sum(1 for item in items if _passed(item)),
        )
        for category, items in sorted(by_category.items())
    ]

    consistency_rate, inconsistent = _consistency(entries)

    failed = [
        FailedFixture(
            fixture_key=_fixture_key(entry),
            category=entry.get("category", "unbekannt"),
            prompt=entry.get("prompt", ""),
            answer_excerpt=(entry.get("answer") or "")[:200],
            outcome=entry.get("outcome", "unbekannt"),
        )
        for entry in entries
        if not _passed(entry)
    ]

    return ReportSummary(
        run_path=run_path,
        total_entries=len(entries),
        categories=categories,
        latency=_latency_stats(entries),
        consistency_rate=consistency_rate,
        inconsistent_fixture_keys=inconsistent,
        failed=failed,
    )


def render_markdown(summary: ReportSummary) -> str:
    lines = [f"# NaMi-AI-Eval-Report: {summary.run_path}", "", f"{summary.total_entries} Log-Zeile(n) insgesamt.", ""]

    lines.append("## Pass-Rate je Kategorie")
    lines.append("")
    lines.append("| Kategorie | bestanden | gesamt | Pass-Rate |")
    lines.append("|---|---|---|---|")
    for category_summary in summary.categories:
        lines.append(
            f"| {category_summary.category} | {category_summary.passed} | {category_summary.total} "
            f"| {category_summary.pass_rate:.0%} |"
        )
    lines.append("")

    if summary.latency:
        lines.append("## Latenz")
        lines.append("")
        lines.append(
            f"min {summary.latency.min_ms:.0f} ms / median {summary.latency.median_ms:.0f} ms / "
            f"p90 {summary.latency.p90_ms:.0f} ms / max {summary.latency.max_ms:.0f} ms "
            f"({summary.latency.count} Messwert(e))"
        )
        lines.append("")

    if summary.consistency_rate is not None:
        lines.append("## Konsistenz ueber Wiederholungen (--repeat)")
        lines.append("")
        lines.append(f"Konsistenz-Rate: {summary.consistency_rate:.0%}")
        if summary.inconsistent_fixture_keys:
            lines.append("")
            lines.append("Inkonsistent (nicht jede Wiederholung landet auf demselben Verdikt):")
            for key in summary.inconsistent_fixture_keys:
                lines.append(f"- {key}")
        lines.append("")

    if summary.failed:
        lines.append("## Fehlgeschlagen (sourceMatch/guardrailMatch nicht erfuellt)")
        lines.append("")
        for failure in summary.failed:
            lines.append(f"### {failure.fixture_key} ({failure.category}, outcome={failure.outcome})")
            lines.append("")
            lines.append(f"Frage: {failure.prompt}")
            lines.append("")
            if failure.answer_excerpt:
                lines.append(f"Antwort (Ausschnitt): {failure.answer_excerpt}")
                lines.append("")
    else:
        lines.append("## Keine Fehlschlaege")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


@dataclass
class FixtureDelta:
    fixture_key: str
    category: str
    before_passed: bool
    after_passed: bool
    latency_delta_ms: float


@dataclass
class RunDiff:
    run_a_path: str
    run_b_path: str
    regressions: list[FixtureDelta]
    improvements: list[FixtureDelta]
    unchanged_count: int


def diff_runs(entries_a: list[dict], entries_b: list[dict], run_a_path: str, run_b_path: str) -> RunDiff:
    """Compares the LAST entry per fixture in each run (the most recent repeat), so a --repeat
    run diffed against a single-shot run still compares like with like."""

    def last_per_fixture(entries: list[dict]) -> dict[str, dict]:
        latest: dict[str, dict] = {}
        for entry in entries:
            latest[_fixture_key(entry)] = entry
        return latest

    by_key_a = last_per_fixture(entries_a)
    by_key_b = last_per_fixture(entries_b)

    regressions: list[FixtureDelta] = []
    improvements: list[FixtureDelta] = []
    unchanged_count = 0

    for key in sorted(set(by_key_a) & set(by_key_b)):
        entry_a, entry_b = by_key_a[key], by_key_b[key]
        passed_a, passed_b = _passed(entry_a), _passed(entry_b)
        latency_delta = (entry_b.get("latencyMs") or 0) - (entry_a.get("latencyMs") or 0)
        delta = FixtureDelta(
            fixture_key=key,
            category=entry_b.get("category", "unbekannt"),
            before_passed=passed_a,
            after_passed=passed_b,
            latency_delta_ms=latency_delta,
        )
        if passed_a and not passed_b:
            regressions.append(delta)
        elif not passed_a and passed_b:
            improvements.append(delta)
        else:
            unchanged_count += 1

    return RunDiff(
        run_a_path=run_a_path,
        run_b_path=run_b_path,
        regressions=regressions,
        improvements=improvements,
        unchanged_count=unchanged_count,
    )


def render_diff_markdown(diff: RunDiff) -> str:
    lines = [f"# NaMi-AI-Eval-Diff: {diff.run_a_path} -> {diff.run_b_path}", ""]

    lines.append(f"{diff.unchanged_count} Fixture(s) unveraendert.")
    lines.append("")

    lines.append(f"## Regressionen ({len(diff.regressions)})")
    lines.append("")
    if diff.regressions:
        for delta in diff.regressions:
            lines.append(f"- {delta.fixture_key} ({delta.category}), Latenzdelta {delta.latency_delta_ms:+.0f} ms")
    else:
        lines.append("Keine.")
    lines.append("")

    lines.append(f"## Verbesserungen ({len(diff.improvements)})")
    lines.append("")
    if diff.improvements:
        for delta in diff.improvements:
            lines.append(f"- {delta.fixture_key} ({delta.category}), Latenzdelta {delta.latency_delta_ms:+.0f} ms")
    else:
        lines.append("Keine.")
    lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def _write_output(markdown: str, output: Optional[Path]) -> None:
    if output is None:
        print(markdown)
        return
    output.write_text(markdown, encoding="utf-8")
    print(f"Report geschrieben nach {output}")


def summarize_command(run_path: Path, output: Optional[Path]) -> int:
    if not run_path.exists():
        print(f"Datei nicht gefunden: {run_path}", file=sys.stderr)
        return 1
    entries = load_jsonl(run_path)
    if not entries:
        print(f"Keine lesbaren Zeilen in {run_path}.", file=sys.stderr)
        return 1
    summary = summarize(entries, str(run_path))
    _write_output(render_markdown(summary), output)
    return 0


def diff_command(run_a_path: Path, run_b_path: Path, output: Optional[Path]) -> int:
    for path in (run_a_path, run_b_path):
        if not path.exists():
            print(f"Datei nicht gefunden: {path}", file=sys.stderr)
            return 1
    entries_a = load_jsonl(run_a_path)
    entries_b = load_jsonl(run_b_path)
    diff = diff_runs(entries_a, entries_b, str(run_a_path), str(run_b_path))
    _write_output(render_diff_markdown(diff), output)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    subparsers = parser.add_subparsers(dest="command", required=True)

    summarize_parser = subparsers.add_parser("summarize", help="Einen Eval-Run zusammenfassen")
    summarize_parser.add_argument("run", type=Path)
    summarize_parser.add_argument("--output", type=Path, default=None)

    diff_parser = subparsers.add_parser("diff", help="Zwei Eval-Runs vergleichen (Vorher/Nachher)")
    diff_parser.add_argument("run_a", type=Path)
    diff_parser.add_argument("run_b", type=Path)
    diff_parser.add_argument("--output", type=Path, default=None)

    args = parser.parse_args()

    if args.command == "summarize":
        return summarize_command(args.run, args.output)
    if args.command == "diff":
        return diff_command(args.run_a, args.run_b, args.output)
    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
