#!/usr/bin/env bash
# Erzeugt test/fixtures/legacy_0_2_8/ mit dem echten Hive-Code der
# App-Version 0.2.8 (Tag v0.2.8) in einem temporaeren git worktree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LEGACY_REF="${LEGACY_REF:-v0.2.8}"
WORKTREE="$(mktemp -d)/nami-legacy-${LEGACY_REF}"
OUT_DIR="$REPO_ROOT/test/fixtures/legacy_0_2_8"

cleanup() {
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$LEGACY_REF" >/dev/null
mkdir -p "$WORKTREE/test/legacy_fixture"
cp "$REPO_ROOT"/tool/legacy_fixture/v0_2_8/*.dart "$WORKTREE/test/legacy_fixture/"
"$REPO_ROOT/tool/legacy_fixture/prepare_legacy_worktree.sh" "$WORKTREE"

(
  cd "$WORKTREE"
  flutter pub get >/dev/null
  LEGACY_FIXTURE_OUT="$OUT_DIR" flutter test test/legacy_fixture/generate_fixture_test.dart
)

echo "Fixture geschrieben nach $OUT_DIR"
ls -la "$OUT_DIR"
