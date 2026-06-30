#!/usr/bin/env bash
# Install prefapp-workflow skills into detected agent harnesses.
# Idempotent — safe to re-run. Symlinks only, never copies.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
NAMESPACE="prefapp-workflow"

echo "prefapp-workflow: installing from $SKILLS_DIR"

# ~/.agents/skills — canonical location, read by pi and OpenCode (both honor it)
mkdir -p "$HOME/.agents/skills"
ln -sfn "$SKILLS_DIR" "$HOME/.agents/skills/$NAMESPACE"
echo "  agents: ~/.agents/skills/$NAMESPACE → $SKILLS_DIR"

# Claude Code — separate location, does not read ~/.agents/skills — one namespace-dir symlink
if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
  mkdir -p "$HOME/.claude/skills"
  ln -sfn "$SKILLS_DIR" "$HOME/.claude/skills/$NAMESPACE"
  echo "  claude: ~/.claude/skills/$NAMESPACE → $SKILLS_DIR"
fi

echo "Done. See README.md for per-harness discovery edge cases."
