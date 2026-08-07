#!/usr/bin/env bash
# Behavior test for install.sh at its CLI seam: run the real script against a
# throwaway HOME and assert on the resulting filesystem layout. No framework.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$REPO_DIR/install.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

AGENTS="$TMP/.agents/skills"
CLAUDE="$TMP/.claude/skills"
WORKFLOW_NS="$AGENTS/prefapp-workflow"
FIRESTARTR_NS="$AGENTS/prefapp-firestartr"

run() { HOME="$TMP" "$INSTALL" "$@"; }
reset() { rm -rf "$TMP/.agents" "$TMP/.claude"; }

assert_flat_links() {
  # Every skill under $1 (a src dir) resolves to a flat symlink under $2 (a dest dir).
  local src_dir="$1" dest="$2" label="$3" src name
  for src in "$src_dir"/*/; do
    src="${src%/}"
    [ -f "$src/SKILL.md" ] || continue
    name="$(basename "$src")"
    [ "$(readlink "$dest/$name")" = "$src" ] || { echo "FAIL: $label link missing/wrong for $name"; exit 1; }
    [ -f "$dest/$name/SKILL.md" ] || { echo "FAIL: $label link for $name does not resolve"; exit 1; }
  done
}

# No option shows help and installs nothing.
HELP="$(run)"
printf '%s' "$HELP" | grep -q -- '--all'
[ ! -e "$AGENTS" ] || { echo "FAIL: help installed skills"; exit 1; }

# Workflow-only install: flat per-skill links in ~/.agents/skills, no namespace dir.
run --workflow >/dev/null
[ ! -e "$WORKFLOW_NS" ] || { echo "FAIL: --workflow created a namespace dir"; exit 1; }
assert_flat_links "$REPO_DIR/skills" "$AGENTS" "agents"
[ ! -e "$AGENTS/firestartr-operation" ] || { echo "FAIL: --workflow installed Firestartr"; exit 1; }

# Firestartr-only install.
reset
run --fs >/dev/null
assert_flat_links "$REPO_DIR/firestartr" "$AGENTS" "agents"
[ ! -e "$AGENTS/tdd" ] || { echo "FAIL: --fs installed workflow"; exit 1; }

# Install both sets and remain idempotent.
reset
run --all >/dev/null
run --all >/dev/null
assert_flat_links "$REPO_DIR/skills" "$AGENTS" "agents"
assert_flat_links "$REPO_DIR/firestartr" "$AGENTS" "agents"

# Claude Code gets one flat link per skill too, never a namespace dir.
reset
mkdir -p "$TMP/.claude"
run --all >/dev/null
[ ! -e "$CLAUDE/prefapp-workflow" ] || { echo "FAIL: claude got a namespace dir"; exit 1; }
assert_flat_links "$REPO_DIR/skills" "$CLAUDE" "claude"
assert_flat_links "$REPO_DIR/firestartr" "$CLAUDE" "claude"

# Re-running is idempotent and does not warn about its own links.
ERR="$(HOME="$TMP" "$INSTALL" --all 2>&1 >/dev/null)"
[ -z "$ERR" ] || { echo "FAIL: rerun warned: $ERR"; exit 1; }

# A stale namespace symlink from a previous version of this script is removed.
reset
mkdir -p "$AGENTS" "$CLAUDE"
ln -sfn "$REPO_DIR/skills" "$WORKFLOW_NS"
ln -sfn "$REPO_DIR/firestartr" "$FIRESTARTR_NS"
run --all >/dev/null
[ ! -e "$WORKFLOW_NS" ] || { echo "FAIL: stale agents namespace link not removed"; exit 1; }
[ ! -e "$FIRESTARTR_NS" ] || { echo "FAIL: stale agents firestartr namespace link not removed"; exit 1; }
assert_flat_links "$REPO_DIR/skills" "$AGENTS" "agents"

# An unrelated pre-existing real directory is preserved, not clobbered — for
# both ~/.claude/skills and ~/.agents/skills.
reset
mkdir -p "$CLAUDE/review" "$AGENTS/review"
touch "$CLAUDE/review/SKILL.md" "$AGENTS/review/SKILL.md"
run --workflow >/dev/null 2>&1
[ ! -L "$CLAUDE/review" ] || { echo "FAIL: clobbered a real claude skill dir"; exit 1; }
[ ! -L "$AGENTS/review" ] || { echo "FAIL: clobbered a real agents skill dir"; exit 1; }

# A real directory whose own SKILL.md frontmatter declares the matching
# managed skill name (the manual-copy workaround) is safely replaced with the
# correct symlink, in both destinations.
reset
mkdir -p "$CLAUDE/tdd" "$AGENTS/tdd"
printf -- '---\nname: tdd\ndescription: stale manual copy\n---\n# stale\n' >"$CLAUDE/tdd/SKILL.md"
printf -- '---\nname: tdd\ndescription: stale manual copy\n---\n# stale\n' >"$AGENTS/tdd/SKILL.md"
run --workflow >/dev/null 2>&1
[ "$(readlink "$CLAUDE/tdd")" = "$REPO_DIR/skills/tdd" ] || { echo "FAIL: claude stale copy not replaced"; exit 1; }
[ "$(readlink "$AGENTS/tdd")" = "$REPO_DIR/skills/tdd" ] || { echo "FAIL: agents stale copy not replaced"; exit 1; }

# ...and a second run is a silent no-op (no re-warning, no changes).
ERR="$(HOME="$TMP" "$INSTALL" --workflow 2>&1 >/dev/null)"
[ -z "$ERR" ] || { echo "FAIL: rerun after safe-replace warned: $ERR"; exit 1; }
[ "$(readlink "$CLAUDE/tdd")" = "$REPO_DIR/skills/tdd" ] || { echo "FAIL: claude link changed on rerun"; exit 1; }

# A real directory whose SKILL.md name does NOT match is left untouched.
reset
mkdir -p "$CLAUDE/review-mine" "$AGENTS/review-mine"
printf -- '---\nname: not-a-managed-skill\n---\n' >"$CLAUDE/review-mine/SKILL.md"
printf -- '---\nname: not-a-managed-skill\n---\n' >"$AGENTS/review-mine/SKILL.md"
mv "$CLAUDE/review-mine" "$CLAUDE/tdd"
mv "$AGENTS/review-mine" "$AGENTS/tdd"
run --workflow >/dev/null 2>&1
[ ! -L "$CLAUDE/tdd" ] || { echo "FAIL: clobbered a mismatched-name claude dir"; exit 1; }
[ ! -L "$AGENTS/tdd" ] || { echo "FAIL: clobbered a mismatched-name agents dir"; exit 1; }

# A real directory with no SKILL.md at all is left untouched.
reset
mkdir -p "$CLAUDE/tdd" "$AGENTS/tdd"
run --workflow >/dev/null 2>&1
[ ! -L "$CLAUDE/tdd" ] || { echo "FAIL: clobbered a SKILL.md-less claude dir"; exit 1; }
[ ! -L "$AGENTS/tdd" ] || { echo "FAIL: clobbered a SKILL.md-less agents dir"; exit 1; }

# A link whose source vanished is cleaned up on the next run.
reset
mkdir -p "$CLAUDE" "$AGENTS"
ln -sfn "$REPO_DIR/skills/gone-away" "$CLAUDE/gone-away"
ln -sfn "$REPO_DIR/skills/gone-away" "$AGENTS/gone-away"
run --workflow >/dev/null 2>&1
[ ! -L "$CLAUDE/gone-away" ] || { echo "FAIL: stale claude link not removed"; exit 1; }
[ ! -L "$AGENTS/gone-away" ] || { echo "FAIL: stale agents link not removed"; exit 1; }

echo "PASS: install.sh options"
