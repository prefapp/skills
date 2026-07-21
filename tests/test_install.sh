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

echo "PASS: install.sh options"
