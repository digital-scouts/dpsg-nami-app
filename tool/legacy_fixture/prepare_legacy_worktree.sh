#!/usr/bin/env bash
# Macht einen git worktree von v0.2.8 baubar.
set -euo pipefail

WORKTREE="$1"

# 0.2.8 referenziert .gitlink (Symlink auf .git) als Asset. In einem worktree
# ist .git eine Datei, daher wird ein Platzhalter angelegt.
rm -rf "$WORKTREE/.gitlink"
mkdir -p "$WORKTREE/.gitlink/refs/heads"
echo "legacy-fixture" >"$WORKTREE/.gitlink/refs/heads/legacy-fixture"
echo "ref: refs/heads/legacy-fixture" >"$WORKTREE/.gitlink/HEAD"

# Die App liest .env als Asset; Werte werden fuer den Seed nicht benoetigt.
touch "$WORKTREE/.env"
