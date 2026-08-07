#!/usr/bin/env bash
# Behavior test for install.sh at its CLI seam: run the real script against a
# throwaway HOME and assert which namespace symlinks exist. No framework.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$REPO_DIR/install.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

WORKFLOW_LINK="$TMP/.agents/skills/prefapp-workflow"
FIRESTARTR_LINK="$TMP/.agents/skills/prefapp-firestartr"

run() { HOME="$TMP" "$INSTALL" "$@"; }
reset() { rm -rf "$TMP/.agents" "$TMP/.claude"; }

# No option shows help and installs nothing.
HELP="$(run)"
printf '%s' "$HELP" | grep -q -- '--all'
[ ! -e "$WORKFLOW_LINK" ] && [ ! -e "$FIRESTARTR_LINK" ] || { echo "FAIL: help installed skills"; exit 1; }

# Workflow-only install.
run --workflow >/dev/null
[ "$(readlink "$WORKFLOW_LINK")" = "$REPO_DIR/skills" ] || { echo "FAIL: --workflow symlink wrong"; exit 1; }
[ ! -e "$FIRESTARTR_LINK" ] || { echo "FAIL: --workflow installed Firestartr"; exit 1; }

# Firestartr-only install.
reset
run --fs >/dev/null
[ "$(readlink "$FIRESTARTR_LINK")" = "$REPO_DIR/firestartr" ] || { echo "FAIL: --fs symlink wrong"; exit 1; }
[ ! -e "$WORKFLOW_LINK" ] || { echo "FAIL: --fs installed workflow"; exit 1; }

# Install both sets and remain idempotent.
reset
run --all >/dev/null
run --all >/dev/null
[ "$(readlink "$WORKFLOW_LINK")" = "$REPO_DIR/skills" ] || { echo "FAIL: --all workflow symlink wrong"; exit 1; }
[ "$(readlink "$FIRESTARTR_LINK")" = "$REPO_DIR/firestartr" ] || { echo "FAIL: --all Firestartr symlink wrong"; exit 1; }

# Claude Code gets one flat link per skill, never a namespace dir.
reset
mkdir -p "$TMP/.claude"
run --all >/dev/null
CLAUDE="$TMP/.claude/skills"
[ ! -e "$CLAUDE/prefapp-workflow" ] || { echo "FAIL: claude got a namespace dir"; exit 1; }
for src in "$REPO_DIR"/skills/*/ "$REPO_DIR"/firestartr/*/; do
  src="${src%/}"
  [ -f "$src/SKILL.md" ] || continue
  name="$(basename "$src")"
  [ "$(readlink "$CLAUDE/$name")" = "$src" ] || { echo "FAIL: claude link missing/wrong for $name"; exit 1; }
  [ -f "$CLAUDE/$name/SKILL.md" ] || { echo "FAIL: claude link for $name does not resolve"; exit 1; }
done

# VSCode Agent gets one flat link per skill directly in ~/.agents/skills.
reset
mkdir -p "$TMP/.vscode"
run --all >/dev/null
AGENTS="$TMP/.agents/skills"
for src in "$REPO_DIR"/skills/*/ "$REPO_DIR"/firestartr/*/; do
  src="${src%/}"
  [ -f "$src/SKILL.md" ] || continue
  name="$(basename "$src")"
  [ "$(readlink "$AGENTS/$name")" = "$src" ] || { echo "FAIL: vscode flat link missing/wrong for $name"; exit 1; }
  [ -f "$AGENTS/$name/SKILL.md" ] || { echo "FAIL: vscode flat link for $name does not resolve"; exit 1; }
done
# Namespace dirs must still coexist.
[ "$(readlink "$AGENTS/prefapp-workflow")" = "$REPO_DIR/skills" ] || { echo "FAIL: namespace dir missing alongside flat links"; exit 1; }
[ "$(readlink "$AGENTS/prefapp-firestartr")" = "$REPO_DIR/firestartr" ] || { echo "FAIL: firestartr namespace dir missing"; exit 1; }

# Re-running is idempotent and does not warn about its own links.
ERR="$(HOME="$TMP" "$INSTALL" --all 2>&1 >/dev/null)"
[ -z "$ERR" ] || { echo "FAIL: rerun warned: $ERR"; exit 1; }

# An unrelated pre-existing skill dir is preserved, not clobbered (Claude).
mkdir -p "$CLAUDE/review-mine" && rm -f "$CLAUDE/review"
mkdir -p "$CLAUDE/review" && touch "$CLAUDE/review/SKILL.md"
run --workflow >/dev/null 2>&1
[ ! -L "$CLAUDE/review" ] || { echo "FAIL: clobbered a real skill dir (claude)"; exit 1; }

# An unrelated pre-existing skill dir is preserved, not clobbered (VSCode Agent).
rm -f "$AGENTS/review"
mkdir -p "$AGENTS/review" && touch "$AGENTS/review/SKILL.md"
run --workflow >/dev/null 2>&1
[ ! -L "$AGENTS/review" ] || { echo "FAIL: clobbered a real skill dir (vscode)"; exit 1; }

# A link whose source vanished is cleaned up on the next run (Claude).
ln -sfn "$REPO_DIR/skills/gone-away" "$CLAUDE/gone-away"
run --workflow >/dev/null 2>&1
[ ! -L "$CLAUDE/gone-away" ] || { echo "FAIL: stale link not removed (claude)"; exit 1; }

# A link whose source vanished is cleaned up on the next run (VSCode Agent).
ln -sfn "$REPO_DIR/skills/gone-away" "$AGENTS/gone-away"
run --workflow >/dev/null 2>&1
[ ! -L "$AGENTS/gone-away" ] || { echo "FAIL: stale link not removed (vscode)"; exit 1; }

echo "PASS: install.sh options"
