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

run() { HOME="$TMP" "$INSTALL" "$@" >/dev/null; }

# (b) Default install: workflow linked, operational NOT created.
run
[ -L "$WORKFLOW_LINK" ] || { echo "FAIL: default did not create workflow symlink"; exit 1; }
[ "$(readlink "$WORKFLOW_LINK")" = "$REPO_DIR/skills" ] || { echo "FAIL: workflow symlink wrong target"; exit 1; }
[ ! -e "$FIRESTARTR_LINK" ] || { echo "FAIL: default created operational symlink"; exit 1; }

# (a) Opt-in: operational symlink created and points at the operational dir;
#     workflow link still intact.
run --with-firestartr
[ -L "$FIRESTARTR_LINK" ] || { echo "FAIL: --with-firestartr did not create operational symlink"; exit 1; }
[ "$(readlink "$FIRESTARTR_LINK")" = "$REPO_DIR/firestartr" ] || { echo "FAIL: operational symlink wrong target"; exit 1; }
[ -L "$WORKFLOW_LINK" ] || { echo "FAIL: opt-in disturbed workflow symlink"; exit 1; }

# (c) Idempotent: re-running the opt-in install leaves both links correct.
run --with-firestartr
[ "$(readlink "$FIRESTARTR_LINK")" = "$REPO_DIR/firestartr" ] || { echo "FAIL: re-run broke operational symlink"; exit 1; }
[ "$(readlink "$WORKFLOW_LINK")" = "$REPO_DIR/skills" ] || { echo "FAIL: re-run broke workflow symlink"; exit 1; }

echo "PASS: install.sh opt-in behavior"
