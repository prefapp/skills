#!/usr/bin/env bash
# Install prefapp-workflow skills into detected agent harnesses.
# Idempotent — safe to re-run. Symlinks only, never copies.
#
# By default installs only the generalized workflow set. Pass --with-firestartr
# to also install the opt-in Firestartr operational skill set.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
NAMESPACE="prefapp-workflow"
FIRESTARTR_DIR="$REPO_DIR/firestartr"
FIRESTARTR_NAMESPACE="prefapp-firestartr"

WITH_FIRESTARTR=0
for arg in "$@"; do
  case "$arg" in
    --with-firestartr) WITH_FIRESTARTR=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Link one source dir into every harness skills location under $namespace.
link_into_harnesses() {
  local src="$1" ns="$2"
  mkdir -p "$HOME/.agents/skills"
  ln -sfn "$src" "$HOME/.agents/skills/$ns"
  echo "  agents: ~/.agents/skills/$ns → $src"
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    mkdir -p "$HOME/.claude/skills"
    ln -sfn "$src" "$HOME/.claude/skills/$ns"
    echo "  claude: ~/.claude/skills/$ns → $src"
  fi
}

echo "prefapp-workflow: installing from $SKILLS_DIR"
link_into_harnesses "$SKILLS_DIR" "$NAMESPACE"

if [ "$WITH_FIRESTARTR" -eq 1 ]; then
  echo "prefapp-firestartr: installing from $FIRESTARTR_DIR"
  link_into_harnesses "$FIRESTARTR_DIR" "$FIRESTARTR_NAMESPACE"
fi

echo "Done. See README.md for per-harness discovery edge cases."
