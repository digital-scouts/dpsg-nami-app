#!/bin/bash
#
# chat_ai/eval/run_eval.sh - Ein Kommando statt drei: prueft zuerst die modellunabhaengige
# Eval-Logik (swift test), fuehrt dann einen echten Lauf von nami-ai-eval gegen
# eval_questions.json/eval_conversations.json aus und formatiert das Ergebnis als
# Markdown-Report (chat_ai/eval/report_eval_run.py). Bricht ab, sobald die Logik-Tests
# fehlschlagen, statt einen (u.U. minutenlangen) echten Modell-Lauf gegen kaputte Logik
# zu verschwenden. Siehe chat_ai/eval/README.md fuer Voraussetzungen (Mac mit aktivierter
# Apple Intelligence).
#
# Nutzung:
#   chat_ai/eval/run_eval.sh [--skip-tests] [--report-output <pfad>] [<nami-ai-eval-optionen>...]
#
# Beispiele:
#   chat_ai/eval/run_eval.sh
#   chat_ai/eval/run_eval.sh --only jargon-sv-mitglieder --skip-conversations
#   chat_ai/eval/run_eval.sh --skip-tests --repeat 3
#
# Alle nicht erkannten Optionen werden unveraendert an `swift run nami-ai-eval`
# durchgereicht (siehe `swift run nami-ai-eval --help`).

set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAMI_AI_KIT_DIR="$REPO_ROOT/ios/NamiAiKit"
REPORT_SCRIPT="$REPO_ROOT/chat_ai/eval/report_eval_run.py"

SKIP_TESTS=0
REPORT_OUTPUT=""
EVAL_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-tests)
      SKIP_TESTS=1
      shift
      ;;
    --report-output)
      REPORT_OUTPUT="$2"
      shift 2
      ;;
    *)
      EVAL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ "$SKIP_TESTS" -eq 0 ]; then
  echo "==> 1/3 Logik-Tests (NamiAiEvalKitTests, kein Modell noetig)"
  (cd "$NAMI_AI_KIT_DIR" && swift test --filter NamiAiEvalKitTests)
  echo ""
else
  echo "==> 1/3 Logik-Tests uebersprungen (--skip-tests)"
  echo ""
fi

echo "==> 2/3 Eval-Lauf (nami-ai-eval, braucht Apple Intelligence)"
RUN_LOG="$(mktemp)"
trap 'rm -f "$RUN_LOG"' EXIT

if [ "${#EVAL_ARGS[@]}" -gt 0 ]; then
  (cd "$NAMI_AI_KIT_DIR" && swift run nami-ai-eval "${EVAL_ARGS[@]}") | tee "$RUN_LOG"
else
  (cd "$NAMI_AI_KIT_DIR" && swift run nami-ai-eval) | tee "$RUN_LOG"
fi
echo ""

JSONL_PATH="$(grep -oE '[^[:space:]]+\.jsonl' "$RUN_LOG" | tail -1 || true)"
if [ -z "$JSONL_PATH" ]; then
  echo "Konnte den Pfad der geschriebenen JSONL-Datei nicht aus der Ausgabe lesen." >&2
  exit 1
fi

if [ -z "$REPORT_OUTPUT" ]; then
  REPORT_OUTPUT="${JSONL_PATH%.jsonl}.md"
fi

echo "==> 3/3 Report formatieren"
python3 "$REPORT_SCRIPT" summarize "$JSONL_PATH" --output "$REPORT_OUTPUT"
echo ""
cat "$REPORT_OUTPUT"
